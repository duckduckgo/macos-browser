//
//  NetworkProtectionServerMocks.swift
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
@testable import NetworkProtection

extension AnyIPAddress: ExpressibleByStringLiteral {

    public init(stringLiteral: String) {
        self.init(stringLiteral)!
    }

}

extension NetworkProtectionServerInfo {

    static let mock = NetworkProtectionServerInfo(name: "Mock Server",
                                                  publicKey: "ovn9RpzUuvQ4XLQt6B3RKuEXGIxa5QpTnehjduZlcSE=",
                                                  hostNames: ["duckduckgo.com"],
                                                  ips: ["192.168.1.1"],
                                                  port: 443,
                                                  attributes: .init(city: "City", country: "Country", timezoneOffset: 0))

    static let hostNameOnly = NetworkProtectionServerInfo(name: "Mock Server",
                                                          publicKey: "ovn9RpzUuvQ4XLQt6B3RKuEXGIxa5QpTnehjduZlcSE=",
                                                          hostNames: ["duckduckgo.com"],
                                                          ips: [],
                                                          port: 443,
                                                          attributes: .init(city: "City", country: "Country", timezoneOffset: 0))

    static let ipAddressOnly = NetworkProtectionServerInfo(name: "Mock Server",
                                                           publicKey: "ovn9RpzUuvQ4XLQt6B3RKuEXGIxa5QpTnehjduZlcSE=",
                                                           hostNames: [],
                                                           ips: ["192.168.1.1"],
                                                           port: 443,
                                                           attributes: .init(city: "City", country: "Country", timezoneOffset: 0))

    static func make(named name: String, withPublicKey publicKey: String = "") -> Self {
        NetworkProtectionServerInfo(name: name,
                                    publicKey: publicKey,
                                    hostNames: ["duckduckgo.com"],
                                    ips: ["192.168.1.1"],
                                    port: 443,
                                    attributes: .init(city: "City", country: "Country", timezoneOffset: 0))
    }

}

extension NetworkProtectionServer {

    static let mockBaseServer = NetworkProtectionServer(registeredPublicKey: nil, allowedIPs: nil, serverInfo: .mock, expirationDate: nil)
    static let mockRegisteredServer = NetworkProtectionServer(registeredPublicKey: "ovn9RpzUuvQ4XLQt6B3RKuEXGIxa5QpTnehjduZlcSE=",
                                                              allowedIPs: ["0.0.0.0/0", "::/0"],
                                                              serverInfo: .mock,
                                                              expirationDate: Date().addingTimeInterval(.day))

    static func baseServer(named name: String, withPublicKey publicKey: String = "ovn9RpzUuvQ4XLQt6B3RKuEXGIxa5QpTnehjduZlcSE=") -> Self {
        return NetworkProtectionServer(registeredPublicKey: publicKey,
                                       allowedIPs: nil,
                                       serverInfo: .make(named: name, withPublicKey: publicKey),
                                       expirationDate: Date().addingTimeInterval(.day))
    }

    static func registeredServer(named name: String, withPublicKey publicKey: String = "ovn9RpzUuvQ4XLQt6B3RKuEXGIxa5QpTnehjduZlcSE=") -> Self {
        return NetworkProtectionServer(registeredPublicKey: publicKey,
                                       allowedIPs: ["0.0.0.0/0", "::/0"],
                                       serverInfo: .make(named: name, withPublicKey: publicKey),
                                       expirationDate: Date().addingTimeInterval(.day))
    }

}
