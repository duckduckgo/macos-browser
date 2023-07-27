//
//  CaptchaService.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import Common

typealias CaptchaTransactionId = String
typealias CaptchaResolveData = String

public enum CaptchaServiceError: Error {
    case cantGenerateCaptchaServiceURL
    case nilTransactionIdWhenSubmittingCaptcha
    case criticalFailureWhenSubmittingCaptcha
    case invalidRequestWhenSubmittingCaptcha
    case timedOutWhenSubmittingCaptcha
    case errorWhenSubmittingCaptcha
    case errorWhenFetchingCaptchaResult
    case nilDataWhenFetchingCaptchaResult
    case timedOutWhenFetchingCaptchaResult
    case failureWhenFetchingCaptchaResult
    case invalidRequestWhenFetchingCaptchaResult
}

struct CaptchaTransaction: Codable {
    enum Message: String, Codable {
        case success = "SUCCESS"
        case invalidRequest = "INVALID_REQUEST"
        case failureTransient = "FAILURE_TRANSIENT"
        case failureCritical = "FAILURE_CRITICAL"
    }

    let message: Message
    let transactionId: String?
}

struct Backend: Codable {
    let pollAttempts, solveAttempts: Int
}

struct Meta: Codable {
    let lastBackend: String
    let backends: [String: Backend]
    let timeToSolution: Double
    let type: String
    let lastUpdated: Double
}

struct CaptchaResult: Codable {

    enum Message: String, Codable {
        case ready = "SOLUTION_READY"
        case notReady = "SOLUTION_NOT_READY"
        case failure = "FAILURE"
        case invalidRequest = "INVALID_REQUEST"
    }

    let data: String?
    let message: Message
    let meta: Meta
}

protocol CaptchaServiceProtocol {

    /// Submits captcha information to the backend to start solving it,
    ///
    /// - Parameters:
    ///   - captchaInfo: A struct that containers a `siteKey`, `url` and `type`
    /// - Returns: `CaptchaTransactionId` an identifier so we can later use to fetch the resolved captcha information
    func submitCaptchaInformation(_ captchaInfo: GetCaptchaInfoResponse,
                                  retries: Int) async throws -> CaptchaTransactionId

    /// Fetches the resolved captcha information with the passed transaction ID.
    ///
    /// - Parameters:
    ///   - transactionID: The transaction ID of the previous submitted captcha information
    ///   - retries: The number of retries until we timed out. Defaults to 100
    ///   - pollingInterval: The time between each poll in seconds. Defaults to 40 seconds
    /// - Returns: `CaptchaResolveData` a string containing the data to resolve the captcha
    func submitCaptchaToBeResolved(for transactionID: CaptchaTransactionId,
                                   retries: Int,
                                   pollingInterval: Int) async throws -> CaptchaResolveData
}

extension CaptchaServiceProtocol {
    func submitCaptchaInformation(_ captchaInfo: GetCaptchaInfoResponse) async throws -> CaptchaTransactionId {
        try await submitCaptchaInformation(captchaInfo, retries: 5)
    }

    func submitCaptchaToBeResolved(for transactionID: CaptchaTransactionId) async throws -> CaptchaResolveData {
        try await submitCaptchaToBeResolved(for: transactionID, retries: 100, pollingInterval: 40)
    }
}

struct CaptchaService: CaptchaServiceProtocol {

    private struct Constants {
        struct URL {
            private static let baseURL = "https://dbp.duckduckgo.com/dbp/captcha/v0/"
            private static let result = "result"

            static let submit = Constants.URL.baseURL + "submit"

            static func result(for transactionID: CaptchaTransactionId) -> String {
                "\(Constants.URL.baseURL)\(Constants.URL.result)?transactionId=\(transactionID)"
            }
        }
    }

    private let urlSession: URLSession
    private let redeemUseCase: RedeemUseCaseProtocol

    init(urlSession: URLSession = URLSession.shared,
         redeemUseCase: RedeemUseCaseProtocol = RedeemUseCase()) {
        self.urlSession = urlSession
        self.redeemUseCase = redeemUseCase
    }

    func submitCaptchaInformation(_ captchaInfo: GetCaptchaInfoResponse,
                                  retries: Int = 5) async throws -> CaptchaTransactionId {
        guard let captchaSubmitResult = try? await submitCaptchaInformationRequest(captchaInfo) else {
            throw CaptchaServiceError.errorWhenSubmittingCaptcha
        }

        switch  captchaSubmitResult.message {
        case .success:
            if let transactionId = captchaSubmitResult.transactionId {
                return transactionId
            } else {
                throw CaptchaServiceError.nilTransactionIdWhenSubmittingCaptcha
            }
        case .failureTransient:
            if retries == 0 {
                throw CaptchaServiceError.timedOutWhenSubmittingCaptcha
            }
            try await Task.sleep(nanoseconds: UInt64(1 * Double(NSEC_PER_SEC)))
            return try await submitCaptchaInformation(captchaInfo, retries: retries - 1)
        case .failureCritical:
            throw CaptchaServiceError.criticalFailureWhenSubmittingCaptcha
        case .invalidRequest:
            throw CaptchaServiceError.invalidRequestWhenSubmittingCaptcha
        }
    }

    private func submitCaptchaInformationRequest(_ captchaInfo: GetCaptchaInfoResponse) async throws -> CaptchaTransaction {
        guard let url = URL(string: Constants.URL.submit) else {
            throw CaptchaServiceError.cantGenerateCaptchaServiceURL
        }
        os_log("Submitting captcha request ...", log: .service)
        var request = URLRequest(url: url)
        let authHeader = try await redeemUseCase.getAuthHeader()
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let bodyObject: [String: Any] = [
            "sitekey": captchaInfo.siteKey,
            "url": captchaInfo.url,
            "type": captchaInfo.type
        ]

        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: bodyObject, options: [])

        let (data, _) = try await urlSession.data(for: request)
        let result = try JSONDecoder().decode(CaptchaTransaction.self, from: data)

        return result
    }

    func submitCaptchaToBeResolved(for transactionID: CaptchaTransactionId,
                                   retries: Int = 100,
                                   pollingInterval: Int = 40) async throws -> CaptchaResolveData {
        guard let captchaResolveResult = try? await submitCaptchaToBeResolvedRequest(transactionID) else {
            throw CaptchaServiceError.errorWhenFetchingCaptchaResult
        }

        switch captchaResolveResult.message {
        case .ready:
            if let data = captchaResolveResult.data {
                os_log("Captcha ready ...", log: .service)
                return data
            } else {
                throw CaptchaServiceError.nilDataWhenFetchingCaptchaResult
            }
        case .notReady:
            os_log("Captcha not ready ...", log: .service)
            if retries == 0 {
                throw CaptchaServiceError.timedOutWhenFetchingCaptchaResult
            }
            try await Task.sleep(nanoseconds: UInt64(pollingInterval) * NSEC_PER_SEC)
            return try await submitCaptchaToBeResolved(for: transactionID, retries: retries - 1, pollingInterval: pollingInterval)
        case .failure:
            os_log("Captcha failure ...", log: .service)
            throw CaptchaServiceError.failureWhenFetchingCaptchaResult
        case .invalidRequest:
            os_log("Captcha invalid request ...", log: .service)
            throw CaptchaServiceError.invalidRequestWhenFetchingCaptchaResult
        }
    }

    private func submitCaptchaToBeResolvedRequest(_ transactionID: CaptchaTransactionId) async throws -> CaptchaResult {
        guard let url = URL(string: Constants.URL.result(for: transactionID)) else {
            throw CaptchaServiceError.cantGenerateCaptchaServiceURL
        }

        var request = URLRequest(url: url)
        let authHeader = try await redeemUseCase.getAuthHeader()
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "GET"

        let (data, _) = try await urlSession.data(for: request)
        let result = try JSONDecoder().decode(CaptchaResult.self, from: data)

        return result
    }
}
