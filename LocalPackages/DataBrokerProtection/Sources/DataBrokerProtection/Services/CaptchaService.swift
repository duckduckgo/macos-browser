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
import os.log

typealias CaptchaTransactionId = String
typealias CaptchaResolveData = String

public enum CaptchaServiceError: Error, Codable {
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
    case cancelled
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
    ///   - pollingInterval: The time between each poll in seconds. Defaults to 1 second
    ///   - attemptId: Identifies the scan or the opt-out attempt
    ///   - shouldRunNextStep: A closure that defines if the retry should keep happening
    /// - Returns: `CaptchaTransactionId` an identifier so we can later use to fetch the resolved captcha information
    func submitCaptchaInformation(_ captchaInfo: GetCaptchaInfoResponse,
                                  retries: Int,
                                  pollingInterval: TimeInterval,
                                  attemptId: UUID,
                                  shouldRunNextStep: @escaping () -> Bool) async throws -> CaptchaTransactionId

    /// Fetches the resolved captcha information with the passed transaction ID.
    ///
    /// - Parameters:
    ///   - transactionID: The transaction ID of the previous submitted captcha information
    ///   - retries: The number of retries until we timed out. Defaults to 100
    ///   - pollingInterval: The time between each poll in seconds. Defaults to 40 seconds
    ///   - attemptId: Identifies the scan or the opt-out attempt
    ///   - shouldRunNextStep: A closure that defines if the retry should keep happening
    /// - Returns: `CaptchaResolveData` a string containing the data to resolve the captcha
    func submitCaptchaToBeResolved(for transactionID: CaptchaTransactionId,
                                   retries: Int,
                                   pollingInterval: TimeInterval,
                                   attemptId: UUID,
                                   shouldRunNextStep: @escaping () -> Bool) async throws -> CaptchaResolveData
}

extension CaptchaServiceProtocol {
    func submitCaptchaInformation(_ captchaInfo: GetCaptchaInfoResponse, attemptId: UUID, shouldRunNextStep: @escaping () -> Bool) async throws -> CaptchaTransactionId {
        try await submitCaptchaInformation(captchaInfo, retries: 5, pollingInterval: 1, attemptId: attemptId, shouldRunNextStep: shouldRunNextStep)
    }

    func submitCaptchaToBeResolved(for transactionID: CaptchaTransactionId, attemptId: UUID, shouldRunNextStep: @escaping () -> Bool) async throws -> CaptchaResolveData {
        try await submitCaptchaToBeResolved(for: transactionID, retries: 100, pollingInterval: 40, attemptId: attemptId, shouldRunNextStep: shouldRunNextStep)
    }
}

struct CaptchaService: CaptchaServiceProtocol {
    private struct Constants {
        static let endpointSubPath = "/dbp/captcha/v0"
    }

    private let urlSession: URLSession
    private let authenticationManager: DataBrokerProtectionAuthenticationManaging
    private let settings: DataBrokerProtectionSettings
    private let servicePixel: DataBrokerProtectionBackendServicePixels

    init(urlSession: URLSession = URLSession.shared,
         authenticationManager: DataBrokerProtectionAuthenticationManaging,
         settings: DataBrokerProtectionSettings = DataBrokerProtectionSettings(),
         servicePixel: DataBrokerProtectionBackendServicePixels = DefaultDataBrokerProtectionBackendServicePixels()) {
        self.urlSession = urlSession
        self.authenticationManager = authenticationManager
        self.settings = settings
        self.servicePixel = servicePixel
    }

    func submitCaptchaInformation(_ captchaInfo: GetCaptchaInfoResponse,
                                  retries: Int = 5,
                                  pollingInterval: TimeInterval = 1,
                                  attemptId: UUID,
                                  shouldRunNextStep: @escaping () -> Bool) async throws -> CaptchaTransactionId {
        guard let captchaSubmitResult = try? await submitCaptchaInformationRequest(captchaInfo, attemptId: attemptId) else {
            throw CaptchaServiceError.errorWhenSubmittingCaptcha
        }

        if !shouldRunNextStep() {
            throw CaptchaServiceError.cancelled
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
            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1000) * NSEC_PER_MSEC)
            return try await submitCaptchaInformation(captchaInfo,
                                                      retries: retries - 1,
                                                      pollingInterval: pollingInterval,
                                                      attemptId: attemptId,
                                                      shouldRunNextStep: shouldRunNextStep)
        case .failureCritical:
            throw CaptchaServiceError.criticalFailureWhenSubmittingCaptcha
        case .invalidRequest:
            throw CaptchaServiceError.invalidRequestWhenSubmittingCaptcha
        }
    }

    private func submitCaptchaInformationRequest(_ captchaInfo: GetCaptchaInfoResponse, attemptId: UUID) async throws -> CaptchaTransaction {
        var urlComponents = URLComponents(url: settings.selectedEnvironment.endpointURL, resolvingAgainstBaseURL: true)
        urlComponents?.path = "\(Constants.endpointSubPath)/submit"
        urlComponents?.queryItems = [URLQueryItem(name: "attemptId", value: attemptId.uuidString)]

        guard let url = urlComponents?.url else {
            throw CaptchaServiceError.cantGenerateCaptchaServiceURL
        }

        Logger.service.debug("Submitting captcha request ...")
        var request = URLRequest(url: url)

        guard let authHeader = await authenticationManager.getAuthHeader() else {
            servicePixel.fireEmptyAccessToken(callSite: .submitCaptchaInformationRequest)
            throw AuthenticationError.noAuthToken
        }

        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let bodyObject: [String: Any] = [
            "siteKey": captchaInfo.siteKey,
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
                                   pollingInterval: TimeInterval = 50,
                                   attemptId: UUID,
                                   shouldRunNextStep: @escaping () -> Bool) async throws -> CaptchaResolveData {

        let captchaResolveResult: CaptchaResult

        do {
            captchaResolveResult = try await submitCaptchaToBeResolvedRequest(transactionID, attemptId: attemptId)
        } catch let error as AuthenticationError where error == .noAuthToken {
            throw AuthenticationError.noAuthToken
        } catch {
            throw CaptchaServiceError.errorWhenFetchingCaptchaResult
        }

        if !shouldRunNextStep() {
            throw CaptchaServiceError.cancelled
        }

        switch captchaResolveResult.message {
        case .ready:
            if let data = captchaResolveResult.data {
                Logger.service.debug("Captcha ready ...")
                return data
            } else {
                throw CaptchaServiceError.nilDataWhenFetchingCaptchaResult
            }
        case .notReady:
            Logger.service.debug("Captcha not ready ...")
            if retries == 0 {
                throw CaptchaServiceError.timedOutWhenFetchingCaptchaResult
            }
            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1000) * NSEC_PER_MSEC)
            return try await submitCaptchaToBeResolved(for: transactionID,
                                                       retries: retries - 1,
                                                       pollingInterval: pollingInterval,
                                                       attemptId: attemptId,
                                                       shouldRunNextStep: shouldRunNextStep)
        case .failure:
            Logger.service.debug("Captcha failure ...")
            throw CaptchaServiceError.failureWhenFetchingCaptchaResult
        case .invalidRequest:
            Logger.service.debug("Captcha invalid request ...")
            throw CaptchaServiceError.invalidRequestWhenFetchingCaptchaResult
        }
    }

    private func submitCaptchaToBeResolvedRequest(_ transactionID: CaptchaTransactionId, attemptId: UUID) async throws -> CaptchaResult {

        var urlComponents = URLComponents(url: settings.selectedEnvironment.endpointURL, resolvingAgainstBaseURL: true)
        urlComponents?.path = "\(Constants.endpointSubPath)/result"

        urlComponents?.queryItems = [
            URLQueryItem(name: "transactionId", value: transactionID),
            URLQueryItem(name: "attemptId", value: attemptId.uuidString)
        ]

        guard let url = urlComponents?.url else {
            throw CaptchaServiceError.cantGenerateCaptchaServiceURL
        }

        var request = URLRequest(url: url)
        guard let authHeader = await authenticationManager.getAuthHeader() else {
            servicePixel.fireEmptyAccessToken(callSite: .submitCaptchaToBeResolvedRequest)
            throw AuthenticationError.noAuthToken
        }

        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "GET"

        let (data, _) = try await urlSession.data(for: request)
        let result = try JSONDecoder().decode(CaptchaResult.self, from: data)

        return result
    }
}
