//
//  AnyIPAddress.swift
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

public enum AnyIPAddress: IPAddress, Hashable, CustomDebugStringConvertible, @unchecked Sendable {
    /// A host specified as an IPv4 address
    case ipv4(IPv4Address)

    /// A host specified an an IPv6 address
    case ipv6(IPv6Address)

    public static func ipv4(_ string: String) -> AnyIPAddress? {
        guard let ip = IPv4Address(string) else { return nil }
        return .ipv4(ip)
    }

    public static func ipv6(_ string: String) -> AnyIPAddress? {
        guard let ip = IPv6Address(string) else { return nil }
        return .ipv6(ip)
    }

    public init?(_ rawValue: Data, _ interface: NWInterface?) {
        if rawValue.count == 4,
           let ip = IPv4Address(rawValue, interface) {

            self = .ipv4(ip)
        } else if let ip = IPv6Address(rawValue, interface) {
            self = .ipv6(ip)
        } else {
            return nil
        }
    }

    public init?(_ string: String) {
        if let ip = IPv6Address(string) {
            self = .ipv6(ip)
        } else if let ip = IPv4Address(string) {
            self = .ipv4(ip)
        } else {
            return nil
        }
    }

    public init(_ address: IPAddress) {
        if let ip = address as? IPv4Address {
            self = .ipv4(ip)
        } else if let ip = address as? IPv6Address {
            self = .ipv6(ip)
        } else {
            self.init(address.rawValue, address.interface)!
        }
    }

    private var ipAddress: IPAddress {
        switch self {
        case .ipv4(let ip):
            return ip
        case .ipv6(let ip):
            return ip
        }
    }

    public var rawValue: Data {
        ipAddress.rawValue
    }

    public var ipv4: IPv4Address? {
        guard case .ipv4(let ip) = self else { return nil }
        return ip
    }

    public var ipv6: IPv6Address? {
        guard case .ipv6(let ip) = self else { return nil }
        return ip
    }

    public var host: NWEndpoint.Host {
        switch self {
        case .ipv4(let ip):
            return .ipv4(ip)
        case .ipv6(let ip):
            return .ipv6(ip)
        }
    }

    public var debugDescription: String {
        switch self {
        case .ipv4(let ip):
            return ip.debugDescription
        case .ipv6(let ip):
            return ip.debugDescription
        }
    }

    public var interface: NWInterface? {
        ipAddress.interface
    }

    public var isLoopback: Bool {
        ipAddress.isLoopback
    }

    public var isLinkLocal: Bool {
        ipAddress.isLinkLocal
    }

    public var isMulticast: Bool {
        ipAddress.isMulticast
    }

}

extension AnyIPAddress: Codable {

    public init(from decoder: Decoder) throws {
        let string = try decoder.singleValueContainer().decode(String.self)
        guard let address = Self.init(string) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Could not decode IP from \(string)", underlyingError: nil))
        }
        self = address
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.debugDescription)
    }

}
