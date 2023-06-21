//
//  NetworkProtectionClientMocks.swift
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
import XCTest
@testable import NetworkProtection

final class NetworkProtectionMockClient: NetworkProtectionClient {
    var redeemReturnValue: Result<String, NetworkProtection.NetworkProtectionClientError>
    var redeemCalled = false

    func redeem(inviteCode: String) async -> Result<String, NetworkProtection.NetworkProtectionClientError> {
        redeemCalled = true
        return redeemReturnValue
    }

    var getServersReturnValue: Result<[NetworkProtectionServer], NetworkProtectionClientError>
    var registerServersReturnValue: Result<[NetworkProtectionServer], NetworkProtectionClientError>

    var getServersCalled = false
    var registerCalled = false

    internal init(getServersReturnValue: Result<[NetworkProtectionServer], NetworkProtectionClientError>,
                  registerServersReturnValue: Result<[NetworkProtectionServer], NetworkProtectionClientError>,
                  redeemReturnValue: Result<String, NetworkProtection.NetworkProtectionClientError>) {
        self.getServersReturnValue = getServersReturnValue
        self.registerServersReturnValue = registerServersReturnValue
        self.redeemReturnValue = redeemReturnValue
    }

    func getServers(authToken: String) async -> Result<[NetworkProtectionServer], NetworkProtectionClientError> {
        getServersCalled = true
        return getServersReturnValue
    }

    func register(authToken: String,
                  publicKey: PublicKey,
                  withServerNamed serverName: String?) async -> Result<[NetworkProtectionServer], NetworkProtectionClientError> {
        registerCalled = true
        return registerServersReturnValue
    }

}
