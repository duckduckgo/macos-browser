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
//import BrowserServicesKit

public struct AccountsService {

    public enum Error: Swift.Error {
        case decodingError
        case serverError(description: String)
        case unknownServerError
        case connectionError

        var description: String { return String(reflecting: self) }
    }

    private static let baseURL = URL(string: "https://quackdev.duckduckgo.com/api/auth")!

    private static let session = {
        let configuration = URLSessionConfiguration.ephemeral
        return URLSession(configuration: configuration)
    }()

    // MARK: -

    public static func getAccessToken(token: String) async -> Result<AccessTokenResponse, AccountsService.Error> {
        await executeAPICall(method: "GET", endpoint: "access-token", headers: ["Authorization": "Bearer " + token])
    }

    public struct AccessTokenResponse: Decodable {
        public let accessToken: String
    }

    // MARK: -

    public static func validateToken(accessToken: String) async -> Result<ValidateTokenResponse, AccountsService.Error> {
        await executeAPICall(method: "GET", endpoint: "validate-token", headers: ["Authorization": "Bearer " + accessToken])
    }

    // swiftlint:disable nesting
    public struct ValidateTokenResponse: Decodable {
        public let account: Account

        public struct Account: Decodable {
            public let email: String
            let entitlements: [Entitlement]
            public let externalID: String

            enum CodingKeys: String, CodingKey {
                case email, entitlements, externalID = "externalId" // no underscores due to keyDecodingStrategy = .convertFromSnakeCase
            }
        }

        struct Entitlement: Decodable {
            let id: Int
            let name: String
            let product: String
        }
    }
    // swiftlint:enable nesting

    // MARK: -

    static func createAccount() async -> Result<CreateAccountResponse, AccountsService.Error> {
        await executeAPICall(method: "POST", endpoint: "account/create", headers: [:])
    }

    struct CreateAccountResponse: Decodable {
        let authToken: String
        let externalID: String
        let status: String

        enum CodingKeys: String, CodingKey {
            case authToken = "authToken", externalID = "externalId", status // no underscores due to keyDecodingStrategy = .convertFromSnakeCase
        }
    }

    // MARK: -

    public static func storeLogin(payload: String, signature: String) async -> Result<StoreLoginResponse, AccountsService.Error> {

        let bodyDict = ["signature": signature,
//                        "signed_data": payload,
                        "store": "apple_app_store"]

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let bodyData = try! encoder.encode(bodyDict)

        let s = String(data: bodyData, encoding: .utf8)
        print(s)

        return await executeAPICall(method: "POST", endpoint: "store-login", headers: [:], body: bodyData)
    }

    public struct StoreLoginResponse: Decodable {
        public let authToken: String
        public let email: String
        public let externalID: String
        public let id: Int
        public let status: String

        enum CodingKeys: String, CodingKey {
            case authToken = "authToken", email, externalID = "externalId", id, status // no underscores due to keyDecodingStrategy = .convertFromSnakeCase
        }
    }

    // MARK: - Private API

    private static func executeAPICall<T>(method: String, endpoint: String, headers: [String: String], body: Data? = nil) async -> Result<T, AccountsService.Error> where T: Decodable {
        let request = makeAPIRequest(method: method, endpoint: endpoint, headers: headers, body: body)

        do {
            let (data, urlResponse) = try await session.data(for: request)

            printDebugInfo(method: method, endpoint: endpoint, data: data, response: urlResponse)

            if let httpResponse = urlResponse as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) {
                if let decodedResponse = decode(T.self, from: data) {
                    return .success(decodedResponse)
                } else {
                    return .failure(.decodingError)
                }
            } else {
                if let decodedResponse = decode(ErrorResponse.self, from: data) {
                    let errorDescription = [method, endpoint, urlResponse.httpStatusCodeAsString ?? "", decodedResponse.error].joined(separator: " ")
                    return .failure(.serverError(description: errorDescription))
                } else {
                    return .failure(.unknownServerError)
                }
            }
        } catch {
            print("Error: \(error)")
            return .failure(.connectionError)
        }
    }

    struct ErrorResponse: Decodable {
        let error: String
    }

    private static func makeAPIRequest(method: String, endpoint: String, headers: [String: String], body: Data?) -> URLRequest {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = headers
        request.httpMethod = method
        request.httpBody = body

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

extension URLResponse {

    var httpStatusCodeAsString: String? {
        guard let httpStatusCode = (self as? HTTPURLResponse)?.statusCode else { return nil }
        return String(httpStatusCode)
    }
}
