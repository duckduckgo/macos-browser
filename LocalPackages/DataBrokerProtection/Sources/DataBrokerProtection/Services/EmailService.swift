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
import os.log

public enum EmailError: Error, Equatable, Codable {
    case cantGenerateURL
    case cantFindEmail
    case invalidEmailLink
    case linkExtractionTimedOut
    case cantDecodeEmailLink
    case unknownStatusReceived(email: String)
    case cancelled
    case httpError(statusCode: Int)
    case unknownHTTPError
}

struct EmailData: Decodable {
    let pattern: String?
    let emailAddress: String
}

protocol EmailServiceProtocol {
    func getEmail(dataBrokerURL: String, attemptId: UUID) async throws -> EmailData
    func getConfirmationLink(from email: String,
                             numberOfRetries: Int,
                             pollingInterval: TimeInterval,
                             attemptId: UUID,
                             shouldRunNextStep: @escaping () -> Bool) async throws -> URL
}

struct EmailService: EmailServiceProtocol {
    private struct Constants {
        static let endpointSubPath = "/dbp/em/v0"
    }

    public let urlSession: URLSession
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

    func getEmail(dataBrokerURL: String, attemptId: UUID) async throws -> EmailData {

        var urlComponents = URLComponents(url: settings.selectedEnvironment.endpointURL, resolvingAgainstBaseURL: true)
        urlComponents?.path = "\(Constants.endpointSubPath)/generate"
        urlComponents?.queryItems = [
            URLQueryItem(name: "dataBroker", value: dataBrokerURL),
            URLQueryItem(name: "attemptId", value: attemptId.uuidString)
        ]

        guard let url = urlComponents?.url else {
            throw EmailError.cantGenerateURL
        }

        var request = URLRequest(url: url)
        guard let authHeader = await authenticationManager.getAuthHeader() else {
            servicePixel.fireEmptyAccessToken(callSite: .getEmail)
            throw AuthenticationError.noAuthToken
        }

        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)
        try validateHTTPResponse(response)

        do {
            return try JSONDecoder().decode(EmailData.self, from: data)
        } catch {
            throw EmailError.cantFindEmail
        }
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        if let httpResponse = response as? HTTPURLResponse {
            if !(200...299).contains(httpResponse.statusCode) {
                servicePixel.fireGenerateEmailHTTPError(statusCode: httpResponse.statusCode)
                throw EmailError.httpError(statusCode: httpResponse.statusCode)
            }
        } else {
            servicePixel.fireGenerateEmailHTTPError(statusCode: 0)
            throw EmailError.unknownHTTPError
        }
    }

    func getConfirmationLink(from email: String,
                             numberOfRetries: Int = 100,
                             pollingInterval: TimeInterval = 30,
                             attemptId: UUID,
                             shouldRunNextStep: @escaping () -> Bool) async throws -> URL {
        let pollingTimeInNanoSecondsSeconds = UInt64(pollingInterval * 1000) * NSEC_PER_MSEC

        guard let emailResult = try? await extractEmailLink(email: email, attemptId: attemptId) else {
            throw EmailError.cantFindEmail
        }

        if !shouldRunNextStep() {
            throw EmailError.cancelled
        }

        switch emailResult.status {
        case .ready:
            if let link = emailResult.link, let url = URL(string: link) {
                Logger.service.debug("Email received")
                return url
            } else {
                Logger.service.debug("Invalid email link")
                throw EmailError.invalidEmailLink
            }
        case .pending:
            if numberOfRetries == 0 {
                throw EmailError.linkExtractionTimedOut
            }
            Logger.service.debug("No email yet. Waiting for a new request ...")
            try await Task.sleep(nanoseconds: pollingTimeInNanoSecondsSeconds)
            return try await getConfirmationLink(from: email,
                                                 numberOfRetries: numberOfRetries - 1,
                                                 pollingInterval: pollingInterval,
                                                 attemptId: attemptId,
                                                 shouldRunNextStep: shouldRunNextStep)
        case .unknown:
            throw EmailError.unknownStatusReceived(email: email)
        }
    }

    private func extractEmailLink(email: String, attemptId: UUID) async throws -> EmailResponse {
        var urlComponents = URLComponents(url: settings.selectedEnvironment.endpointURL, resolvingAgainstBaseURL: true)
        urlComponents?.path = "\(Constants.endpointSubPath)/links"
        urlComponents?.queryItems = [
            URLQueryItem(name: "e", value: email),
            URLQueryItem(name: "attemptId", value: attemptId.uuidString)
        ]

        guard let url = urlComponents?.url else {
            throw EmailError.cantGenerateURL
        }

        var request = URLRequest(url: url)

        guard let authHeader = await authenticationManager.getAuthHeader() else {
            servicePixel.fireEmptyAccessToken(callSite: .extractEmailLink)
            throw AuthenticationError.noAuthToken
        }

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
