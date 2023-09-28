//
//  ReedemCodeServices.swift
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

public protocol DataBrokerProtectionRedeemUseCase {
    /// Method to know if we should ask for an invite code when selecting the DataBrokerProtectionPackage
    ///
    /// - Returns: `true` if we need the user to enter an invite code
    ///            `false` in othercase
    func shouldAskForInviteCode() -> Bool

    /// Tries to redeem an invite code. Throws in case there was an issue when trying to redeem the invite code.
    ///
    /// - Parameters:
    ///   - inviteCode: An invite code used to reedem access to data broker protection
    func redeem(inviteCode: String) async throws

    /// Returns the auth header needed for the authenticated endpoints.
    ///
    /// In case there is no auth header present, tries to fetch a new access token with the saved invite code.
    ///
    /// - Returns: `String` a string that contains the bearer access token
    func getAuthHeader() async throws -> String
}

public protocol AuthenticationRepository {
    func getInviteCode() -> String?
    func getAccessToken() -> String?

    func save(accessToken: String)
    func save(inviteCode: String)
}

public protocol DataBrokerProtectionAuthenticationService {
    /// Reedems an invite code. This will return an access token that needs to be used to authenticate data broker protection requests.
    ///
    /// - Parameters:
    ///   - inviteCode: An invite code used to reedem access to data broker protection
    /// - Returns: `accessToken: String` a string that contains the access token needed for future authenticated requests
    func redeem(inviteCode: String) async throws -> String
}

public final class RedeemUseCase: DataBrokerProtectionRedeemUseCase {
    private let authenticationService: DataBrokerProtectionAuthenticationService
    private let authenticationRepository: AuthenticationRepository

    public init(authenticationService: DataBrokerProtectionAuthenticationService = AuthenticationService(),
                authenticationRepository: AuthenticationRepository = UserDefaultsAuthenticationData()) {
        self.authenticationService = authenticationService
        self.authenticationRepository = authenticationRepository
    }

    public func shouldAskForInviteCode() -> Bool {
        authenticationRepository.getAccessToken() == nil
    }

    public func redeem(inviteCode: String) async throws {
        let accessToken = try await authenticationService.redeem(inviteCode: inviteCode)
        authenticationRepository.save(accessToken: accessToken)
    }

    public func getAuthHeader() async throws -> String {
        var accessToken = authenticationRepository.getAccessToken() ?? ""

        if accessToken.isEmpty {
            guard let inviteCode = authenticationRepository.getInviteCode() else {
                throw AuthenticationError.noInviteCode
            }

            accessToken = try await authenticationService.redeem(inviteCode: inviteCode)
            authenticationRepository.save(accessToken: accessToken)
        }

        return "bearer \(accessToken)"
    }
}

// ⚠️ NOTE: This is just a temporary solution. We should not store the access token on User Defaults.
// The access token will be saved in the secure database once we have that in place.
public final class UserDefaultsAuthenticationData: AuthenticationRepository {
    struct Keys {
        static let accessTokenKey = "dbp:accessTokenKey"
        static let inviteCodeKey = "dbp:inviteCodeKey"
    }

    // Initialize this constant with the DBP API Dev Access Token on Bitwarden if you do not want to use the redeem endpoint.
    private let developmentToken: String? = nil

    public init() {}

    public func getInviteCode() -> String? {
        UserDefaults.standard.string(forKey: Keys.inviteCodeKey)
    }

    public func getAccessToken() -> String? {
        UserDefaults.standard.string(forKey: Keys.accessTokenKey) ?? developmentToken
    }

    public func save(accessToken: String) {
        UserDefaults.standard.set(accessToken, forKey: Keys.accessTokenKey)
    }

    public func save(inviteCode: String) {
        UserDefaults.standard.set(inviteCode, forKey: Keys.inviteCodeKey)
    }
}

public enum AuthenticationError: Error, Equatable {
    case noInviteCode
    case cantGenerateURL
    case issueRedeemingInviteCode(error: String)
}

struct RedeemResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case accessToken
        case message
    }

    let accessToken: String?
    let message: String?
}

public struct AuthenticationService: DataBrokerProtectionAuthenticationService {
    private struct Constants {
        static let redeemURL = "https://dbp.duckduckgo.com/dbp/redeem?"
    }

    private let urlSession: URLSession

    public init(urlSession: URLSession = URLSession.shared) {
        self.urlSession = urlSession
    }

    public func redeem(inviteCode: String) async throws -> String {
        guard let url = URL(string: Constants.redeemURL + "code=\(inviteCode)") else {
            throw AuthenticationError.cantGenerateURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, _) = try await urlSession.data(for: request)

        let result = try JSONDecoder().decode(RedeemResponse.self, from: data)

        if let accessToken = result.accessToken {
            return accessToken
        } else {
            throw AuthenticationError.issueRedeemingInviteCode(error: result.message ?? "Unknown")
        }
    }
}
