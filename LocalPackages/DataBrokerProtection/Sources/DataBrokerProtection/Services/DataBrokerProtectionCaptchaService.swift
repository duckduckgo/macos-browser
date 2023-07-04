//
//  DataBrokerProtectionCaptchaService.swift
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

typealias CaptchaTransactionId = String

public enum CaptchaServiceError: Error {
    case cantGenerateCaptchaServiceURL
    case nilTransactionIdWhenSubmittingCaptcha
    case criticalFailureWhenSubmittingCaptcha
    case invalidRequestWhenSubmittingCaptcha
    case timedOutWhenSubmittingCaptcha
    case errorWhenSubmittingCaptcha
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

public struct DataBrokerProtectionCaptchaService {

    private struct Constants {
        struct URL {
            static let submit = "submit"
            static let baseURL = "https://dbp.duckduckgo.com/dbp/captcha/v0/"
        }
    }

    private let urlSession: URLSession

    public init(urlSession: URLSession = URLSession.shared) {
        self.urlSession = urlSession
    }

    func submitCaptchaInformation(_ captchaInfo: GetCaptchaInfoResponse,
                                  retries: Int = 5) async throws -> CaptchaTransactionId {
        guard let captchaSubmitResult = try? await submitCaptchaRequest(captchaInfo) else {
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

    private func submitCaptchaRequest(_ captchaInfo: GetCaptchaInfoResponse) async throws -> CaptchaTransaction {
        guard let url = URL(string: Constants.URL.baseURL + Constants.URL.submit) else {
            throw CaptchaServiceError.cantGenerateCaptchaServiceURL
        }

        var request = URLRequest(url: url)
        request.setValue(Headers.authorizationHeader, forHTTPHeaderField: "Authorization")
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
}
