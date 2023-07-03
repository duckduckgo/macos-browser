//
//  NetworkProtectionServer.swift
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

/// Represents a server returned by the backend. This value can be used to present to the user and allow them to select which server to register with.
/// This type also tracks whether a given server has been registered with, and the timestamp at which this was most recently done.
public struct NetworkProtectionServer: Codable, Equatable, Sendable {

    // MARK: - Computed Properties

    public var isRegistered: Bool {
        return registeredPublicKey != nil && allowedIPs != nil
    }

    public func isRegistered(with publicKey: PublicKey) -> Bool {
        return registeredPublicKey == publicKey.base64Key && allowedIPs != nil
    }

    public var serverName: String {
        return serverInfo.name
    }

    // MARK: - Properties

    /// Represents the public key value that is registered with the server.
    public let registeredPublicKey: String?

    public let allowedIPs: [String]?

    /// The last date at which registration took place. This may be used to determine whether a key needs to be refreshed.
    public let registrationDate = Date()
    public let expirationDate: Date?

    public let serverInfo: NetworkProtectionServerInfo

    // MARK: - Protocol Conformance

    enum CodingKeys: String, CodingKey {
        case registeredPublicKey = "publicKey"
        case allowedIPs
        case serverInfo = "server"
        case expirationDate = "expiresAt"
    }

    init(registeredPublicKey: String?, allowedIPs: [String]?, serverInfo: NetworkProtectionServerInfo, expirationDate: Date?) {
        self.registeredPublicKey = registeredPublicKey
        self.allowedIPs = allowedIPs
        self.expirationDate = expirationDate
        self.serverInfo = serverInfo
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.registeredPublicKey == rhs.registeredPublicKey && lhs.allowedIPs == rhs.allowedIPs && lhs.serverInfo == rhs.serverInfo
    }
}
