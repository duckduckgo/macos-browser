//
//  NetworkProtectionClient.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

public protocol NetworkProtectionClient {
    func redeem(inviteCode: String) async -> Result<String, NetworkProtectionClientError>
    func getServers(authToken: String) async -> Result<[NetworkProtectionServer], NetworkProtectionClientError>
    func register(authToken: String,
                  publicKey: PublicKey,
                  withServerNamed serverName: String?) async -> Result<[NetworkProtectionServer], NetworkProtectionClientError>

}

public enum NetworkProtectionClientError: Error, NetworkProtectionErrorConvertible {
    case failedToFetchServerList(Error?)
    case failedToParseServerListResponse(Error)
    case failedToEncodeRegisterKeyRequest
    case failedToFetchRegisteredServers(Error?)
    case failedToParseRegisteredServersResponse(Error)
    case failedToEncodeRedeemRequest
    case invalidInviteCode
    case failedToRedeemInviteCode(Error?)
    case failedToParseRedeemResponse(Error)
    case invalidAuthToken

    var networkProtectionError: NetworkProtectionError {
        switch self {
        case .failedToFetchServerList(let error): return .failedToFetchServerList(error)
        case .failedToParseServerListResponse(let error): return .failedToParseServerListResponse(error)
        case .failedToEncodeRegisterKeyRequest: return .failedToEncodeRegisterKeyRequest
        case .failedToFetchRegisteredServers(let error): return .failedToFetchRegisteredServers(error)
        case .failedToParseRegisteredServersResponse(let error): return .failedToParseRegisteredServersResponse(error)
        case .failedToEncodeRedeemRequest: return .failedToEncodeRedeemRequest
        case .invalidInviteCode: return .invalidInviteCode
        case .failedToRedeemInviteCode(let error): return .failedToRedeemInviteCode(error)
        case .failedToParseRedeemResponse(let error): return .failedToParseRedeemResponse(error)
        case .invalidAuthToken: return .invalidAuthToken
        }
    }
}

struct RegisterKeyRequestBody: Encodable {
    let publicKey: String
    let server: String?

    init(publicKey: PublicKey, server: String?) {
        self.publicKey = publicKey.base64Key
        self.server = server
    }
}

struct RedeemRequestBody: Encodable {
    let code: String
}

struct RedeemResponse: Decodable {
    let token: String
}

public final class NetworkProtectionBackendClient: NetworkProtectionClient {

    enum Constants {
        static let developmentEndpoint = URL(string: "https://staging.netp.duckduckgo.com")!
    }

    private enum DecoderError: Error {
        case failedToDecode(key: String)
    }

    var serversURL: URL {
        Constants.developmentEndpoint.appending("/servers")
    }

    var registerKeyURL: URL {
        Constants.developmentEndpoint.appending("/register")
    }

    var redeemURL: URL {
        Constants.developmentEndpoint.appending("/redeem")
    }

    private let decoder: JSONDecoder = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withFullTime, .withFractionalSeconds]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom({ decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            guard let date = formatter.date(from: dateString) else {
                throw DecoderError.failedToDecode(key: container.codingPath.last?.stringValue ?? String(describing: container.codingPath))
            }

            return date
        })

        return decoder
    }()

    public init() {}

    public func getServers(authToken: String) async -> Result<[NetworkProtectionServer], NetworkProtectionClientError> {
        var request = URLRequest(url: serversURL)
        request.setValue("bearer \(authToken)", forHTTPHeaderField: "Authorization")
        let downloadedData: Data

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                return .failure(.failedToFetchServerList(nil))
            }
            switch response.statusCode {
            case 200: downloadedData = data
            case 401: return .failure(.invalidAuthToken)
            default: return .failure(.failedToFetchServerList(nil))
            }
        } catch {
            return .failure(NetworkProtectionClientError.failedToFetchServerList(error))
        }

        do {
            let decodedServers = try decoder.decode([NetworkProtectionServer].self, from: downloadedData)
            return .success(decodedServers)
        } catch {
            return .failure(NetworkProtectionClientError.failedToParseServerListResponse(error))
        }
    }

    public func register(authToken: String,
                         publicKey: PublicKey,
                         withServerNamed serverName: String? = nil) async -> Result<[NetworkProtectionServer], NetworkProtectionClientError> {
        let requestBody = RegisterKeyRequestBody(publicKey: publicKey, server: serverName)
        let requestBodyData: Data

        do {
            requestBodyData = try JSONEncoder().encode(requestBody)
        } catch {
            return .failure(NetworkProtectionClientError.failedToEncodeRegisterKeyRequest)
        }

        var request = URLRequest(url: registerKeyURL)
        request.setValue("bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = requestBodyData

        let responseData: Data

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                return .failure(.failedToFetchRegisteredServers(nil))
            }
            switch response.statusCode {
            case 200: responseData = data
            case 401: return .failure(.invalidAuthToken)
            default: return .failure(.failedToFetchRegisteredServers(nil))
            }
        } catch {
            return .failure(NetworkProtectionClientError.failedToFetchRegisteredServers(error))
        }

        do {
            let decodedServers = try decoder.decode([NetworkProtectionServer].self, from: responseData)
            return .success(decodedServers)
        } catch {
            return .failure(NetworkProtectionClientError.failedToParseRegisteredServersResponse(error))
        }
    }

    public func redeem(inviteCode: String) async -> Result<String, NetworkProtectionClientError> {
        let requestBody = RedeemRequestBody(code: inviteCode)
        let requestBodyData: Data
        do {
            requestBodyData = try JSONEncoder().encode(requestBody)
        } catch {
            return .failure(.failedToEncodeRedeemRequest)
        }

        var request = URLRequest(url: redeemURL)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = requestBodyData

        let responseData: Data

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                return .failure(.failedToRedeemInviteCode(nil))
            }
            switch response.statusCode {
            case 200: responseData = data
            case 400: return .failure(.invalidInviteCode)
            default: return .failure(.failedToRedeemInviteCode(nil))
            }
        } catch {
            return .failure(NetworkProtectionClientError.failedToRedeemInviteCode(error))
        }

        do {
            let decodedRedemptionResponse = try decoder.decode(RedeemResponse.self, from: responseData)
            return .success(decodedRedemptionResponse.token)
        } catch {
            return .failure(NetworkProtectionClientError.failedToParseRedeemResponse(error))
        }
    }

}

extension URL {

    func appending(_ path: String) -> URL {
        if #available(macOS 13.0, *) {
            return appending(path: path)
        } else {
            return appendingPathComponent(path)
        }
    }

}
