//
//  DataBrokerProtectionEmailService.swift
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

public enum EmailError: Error, Equatable {
    case cantGenerateURL
    case cantFindEmail
    case invalidEmailLink
    case linkExtractionTimedOut
    case cantDecodeEmailLink
    case unknownStatusReceived(email: String)
}

protocol EmailServiceProtocol {
    func getEmail() async throws -> String
    func getConfirmationLink(from email: String,
                             numberOfRetries: Int,
                             pollingIntervalInSeconds: Int) async throws -> URL
}

struct EmailService: EmailServiceProtocol {
    private struct Constants {
        static let baseUrl = "https://dbp.duckduckgo.com/dbp/em/v0"
    }

    public let urlSession: URLSession
    private let redeemUseCase: DataBrokerProtectionRedeemUseCase

    init(urlSession: URLSession = URLSession.shared,
         redeemUseCase: DataBrokerProtectionRedeemUseCase = RedeemUseCase()) {
        self.urlSession = urlSession
        self.redeemUseCase = redeemUseCase
    }

    func getEmail() async throws -> String {
        guard let url = URL(string: Constants.baseUrl + "/generate") else {
            throw EmailError.cantGenerateURL
        }

        var request = URLRequest(url: url)
        let authHeader = try await redeemUseCase.getAuthHeader()
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        let (data, _) = try await urlSession.data(for: request)

        if let resJson = try? JSONSerialization.jsonObject(with: data) as? [String: AnyObject],
           let email = resJson["emailAddress"] as? String {
            return email
        } else {
            throw EmailError.cantFindEmail
        }
    }

    func getConfirmationLink(from email: String,
                             numberOfRetries: Int = 100,
                             pollingIntervalInSeconds: Int = 30) async throws -> URL {
        let pollingTimeInNanoSecondsSeconds = UInt64(pollingIntervalInSeconds) * NSEC_PER_SEC

        guard let emailResult = try? await extractEmailLink(email: email) else {
            throw EmailError.cantFindEmail
        }

        switch emailResult.status {
        case .ready:
            if let link = emailResult.link, let url = URL(string: link) {
                os_log("Email received", log: .service)
                return url
            } else {
                os_log("Invalid email link", log: .service)
                throw EmailError.invalidEmailLink
            }
        case .pending:
            if numberOfRetries == 0 {
                throw EmailError.linkExtractionTimedOut
            }
            os_log("No email yet. Waiting for a new request ...", log: .service)
            try await Task.sleep(nanoseconds: pollingTimeInNanoSecondsSeconds)
            return try await getConfirmationLink(from: email, numberOfRetries: numberOfRetries - 1, pollingIntervalInSeconds: pollingIntervalInSeconds)
        case .unknown:
            throw EmailError.unknownStatusReceived(email: email)
        }
    }

    private func extractEmailLink(email: String) async throws -> EmailResponse {
        guard let url = URL(string: Constants.baseUrl + "/links?e=\(email)") else {
            throw EmailError.cantGenerateURL
        }

        var request = URLRequest(url: url)
        let authHeader = try await redeemUseCase.getAuthHeader()
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        let (data, _) = try await urlSession.data(for: request)

        return try JSONDecoder().decode(EmailResponse.self, from: data)
    }
}

internal struct EmailResponse: Codable {
    enum Status: String, Codable {
        case ready
        case unknown
        case pending
    }

    let status: Status
    let link: String?
}
