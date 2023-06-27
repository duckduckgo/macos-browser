//
//  AccountsService.swift
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
import BrowserServicesKit

struct AccountsService {

    private static let baseURL = URL(string: "https://quackdev.duckduckgo.com/api/auth")!
    private static let session = URLSession(configuration: .ephemeral)

    // MARK: -
    static func getAccessToken() async throws -> AccessTokenResponse? {
        try await executeAPICall(method: "GET", endpoint: "access-token", headers: EmailManager().emailHeaders)
    }

    struct AccessTokenResponse: Decodable {
        let accessToken: String
    }

    // MARK: -
    static func validateToken(accessToken: String) async throws -> ValidateTokenResponse? {
        try await executeAPICall(method: "GET", endpoint: "validate-token", headers: ["Authorization": "Bearer " + accessToken])
    }

    struct ValidateTokenResponse: Decodable {
        let account: Account

        struct Account: Decodable {
            let email: String
            let entitlements: [Entitlement]
        }

        struct Entitlement: Decodable {
            let id: Int
            let name: String
            let product: String
        }
    }
}

extension AccountsService {

    private static func executeAPICall<T>(method: String, endpoint: String, headers: [String: String]) async throws -> T? where T: Decodable {
        let request = makeAPIRequest(method: method, endpoint: endpoint, headers: headers)
        let (data, urlResponse) = try await session.data(for: request)

        printDebugInfo(method: method, endpoint: endpoint, data: data, response: urlResponse)

        return decode(T.self, from: data)
    }

    private static func makeAPIRequest(method: String, endpoint: String, headers: [String: String]) -> URLRequest {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = headers
        request.httpMethod = method

        return request
    }

    private static func decode<T>(_: T.Type, from data: Data) -> T? where T: Decodable {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return try? decoder.decode(T.self, from: data)
    }

    private static func printDebugInfo(method: String, endpoint: String, data: Data, response: URLResponse) {
        print("[\((response as? HTTPURLResponse)!.statusCode)] \(method) /\(endpoint) :: \(String(data: data, encoding: .utf8) ?? "")" )
    }
}
