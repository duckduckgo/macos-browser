//
//  NetworkProtectionClient.swift
//  DuckDuckGo
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

    func getServers() async -> Result<[NetworkProtectionServer], NetworkProtectionClientError>
    func register(publicKey: PublicKey,
                  withServer: NetworkProtectionServerInfo) async -> Result<[NetworkProtectionServer], NetworkProtectionClientError>

}

public enum NetworkProtectionClientError: Error, NetworkProtectionErrorConvertible {
    case failedToFetchServerList
    case failedToParseServerListResponse(Error)
    case failedToEncodeRegisterKeyRequest
    case failedToFetchRegisteredServers
    case failedToParseRegisteredServersResponse(Error)

    var networkProtectionError: NetworkProtectionError {
        switch self {
        case .failedToFetchServerList: return .failedToFetchServerList
        case .failedToParseServerListResponse(let error): return .failedToParseServerListResponse(error)
        case .failedToEncodeRegisterKeyRequest: return .failedToEncodeRegisterKeyRequest
        case .failedToFetchRegisteredServers: return .failedToFetchRegisteredServers
        case .failedToParseRegisteredServersResponse(let error): return .failedToParseRegisteredServersResponse(error)
        }
    }
}

struct RegisterKeyRequestBody: Encodable {
    let publicKey: String
    let server: String

    init(publicKey: PublicKey, server: String ) {
        self.publicKey = publicKey.base64Key
        self.server = server
    }
}

public final class NetworkProtectionBackendClient: NetworkProtectionClient {

    enum Constants {
        static let developmentEndpoint = URL(string: "https://on-dev.goduckgo.com")!
    }

    var serversURL: URL {
        Constants.developmentEndpoint.appending("/servers")
    }

    var registerKeyURL: URL {
        Constants.developmentEndpoint.appending("/register")
    }

    public init() {}

    public func getServers() async -> Result<[NetworkProtectionServer], NetworkProtectionClientError> {
        let downloadedData: Data

        do {
            let (data, _) = try await URLSession.shared.data(from: serversURL)
            downloadedData = data
        } catch {
            return .failure(NetworkProtectionClientError.failedToFetchServerList)
        }

        do {
            let decodedServers = try JSONDecoder().decode([NetworkProtectionServer].self, from: downloadedData)
            return .success(decodedServers)
        } catch {
            return .failure(NetworkProtectionClientError.failedToParseServerListResponse(error))
        }
    }

    public func register(publicKey: PublicKey,
                         withServer server: NetworkProtectionServerInfo) async -> Result<[NetworkProtectionServer], NetworkProtectionClientError> {
        let requestBody = RegisterKeyRequestBody(publicKey: publicKey, server: server.name)
        let requestBodyData: Data

        do {
            requestBodyData = try JSONEncoder().encode(requestBody)
        } catch {
            return .failure(NetworkProtectionClientError.failedToEncodeRegisterKeyRequest)
        }

        var request = URLRequest(url: registerKeyURL)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = requestBodyData

        let responseData: Data

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            responseData = data
        } catch {
            return .failure(NetworkProtectionClientError.failedToFetchRegisteredServers)
        }

        do {
            let decodedServers = try JSONDecoder().decode([NetworkProtectionServer].self, from: responseData)
            return .success(decodedServers)
        } catch {
            return .failure(NetworkProtectionClientError.failedToParseRegisteredServersResponse(error))
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
