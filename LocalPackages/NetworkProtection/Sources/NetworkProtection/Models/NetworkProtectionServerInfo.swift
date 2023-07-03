//
//  NetworkProtectionServerInfo.swift
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
import Network

/// Represents connectivity and location information about a server. This object is retrieved from the `/servers` and `/register` endpoints.
/// The server may have an array of hostnames, IPs, or both.
///
/// - Note: The server name is used to register a public key with a given server before connecting to it.
public struct NetworkProtectionServerInfo: Codable, Equatable, Sendable {

    public struct ServerAttributes: Codable, Equatable, Sendable {
        public let city: String
        public let country: String
        public let timezoneOffset: Int

        enum CodingKeys: String, CodingKey {
            case city
            case country
            case timezoneOffset = "tzOffset"
        }
    }

    public let name: String
    public let publicKey: String
    public let hostNames: [String]
    public let ips: [AnyIPAddress]
    public let port: UInt16
    public let attributes: ServerAttributes

    enum CodingKeys: String, CodingKey {
        case name
        case publicKey
        case hostNames = "hostnames"
        case ips
        case port
        case attributes
    }

}

extension NetworkProtectionServerInfo {

    /// Returns the physical location of the server, if one is available. For instance, this may return "Amsterdam, NL". If location attributes are not present, this will return the server name.
    public var serverLocation: String {
        return "\(attributes.city), \(attributes.country.localizedUppercase)"
    }

    /// Calculates the total available addresses for this server.
    public var endpoints: [Endpoint] {
        let port = NWEndpoint.Port(integerLiteral: port)
        return (hostNames.map({ NWEndpoint.Host($0) }) + ips.map(\.host)).map { Endpoint(host: $0, port: port) }
    }

    /// first available server Endpoint
    public var endpoint: Endpoint? {
        let port = NWEndpoint.Port(integerLiteral: port)
        guard let host = hostNames.first.map({ NWEndpoint.Host($0) }) ?? ips.first?.host else { return nil }
        return Endpoint(host: host, port: port)
    }

    /// first available IPv4 address
    public var ipv4: IPv4Address? {
        ips.lazy.compactMap(\.ipv4).first
    }

}
