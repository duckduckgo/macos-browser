//
//  EmailService.swift
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

public enum EmailError: Error, Equatable, Codable {
    case cantGenerateURL
    case cantFindEmail
    case invalidEmailLink
    case linkExtractionTimedOut
    case cantDecodeEmailLink
    case unknownStatusReceived(email: String)
    case cancelled
}

struct EmailData: Decodable {
    let pattern: String?
    let emailAddress: String
}

protocol EmailServiceProtocol {
    func getEmail(dataBrokerURL: String?) async throws -> EmailData
    func getConfirmationLink(from email: String,
                             numberOfRetries: Int,
                             pollingInterval: TimeInterval,
                             shouldRunNextStep: @escaping () -> Bool) async throws -> URL
}

struct EmailService: EmailServiceProtocol {
    private struct Constants {
        static let endpointSubPath = "/dbp/em/v0"
    }

    public let urlSession: URLSession
    private let redeemUseCase: DataBrokerProtectionRedeemUseCase
    private let settings: DataBrokerProtectionSettings

    init(urlSession: URLSession = URLSession.shared,
         redeemUseCase: DataBrokerProtectionRedeemUseCase = RedeemUseCase(),
         settings: DataBrokerProtectionSettings = DataBrokerProtectionSettings()) {
        self.urlSession = urlSession
        self.redeemUseCase = redeemUseCase
        self.settings = settings
    }

    func getEmail(dataBrokerURL: String? = nil) async throws -> EmailData {
        var urlComponents = URLComponents(url: settings.selectedEnvironment.endpointURL, resolvingAgainstBaseURL: true)
        urlComponents?.path = "\(Constants.endpointSubPath)/generate"

        if let dataBrokerValue = dataBrokerURL {
            urlComponents?.queryItems = [URLQueryItem(name: "dataBroker", value: dataBrokerValue)]
        }

        guard let url = urlComponents?.url else {
            throw EmailError.cantGenerateURL
        }

        var request = URLRequest(url: url)
        let authHeader = try await redeemUseCase.getAuthHeader()
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        let (data, _) = try await urlSession.data(for: request)

        do {
            return try JSONDecoder().decode(EmailData.self, from: data)
        } catch {
            throw EmailError.cantFindEmail
        }
    }

    func getConfirmationLink(from email: String,
                             numberOfRetries: Int = 100,
                             pollingInterval: TimeInterval = 30,
                             shouldRunNextStep: @escaping () -> Bool) async throws -> URL {
        let pollingTimeInNanoSecondsSeconds = UInt64(pollingInterval * 1000) * NSEC_PER_MSEC

        guard let emailResult = try? await extractEmailLink(email: email) else {
            throw EmailError.cantFindEmail
        }

        if !shouldRunNextStep() {
            throw EmailError.cancelled
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
            return try await getConfirmationLink(from: email,
                                                 numberOfRetries: numberOfRetries - 1,
                                                 pollingInterval: pollingInterval,
                                                 shouldRunNextStep: shouldRunNextStep)
        case .unknown:
            throw EmailError.unknownStatusReceived(email: email)
        }
    }

    private func extractEmailLink(email: String) async throws -> EmailResponse {
        var urlComponents = URLComponents(url: settings.selectedEnvironment.endpointURL, resolvingAgainstBaseURL: true)
        urlComponents?.path = "\(Constants.endpointSubPath)/links"
        urlComponents?.queryItems = [URLQueryItem(name: "e", value: email)]

        guard let url = urlComponents?.url else {
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
