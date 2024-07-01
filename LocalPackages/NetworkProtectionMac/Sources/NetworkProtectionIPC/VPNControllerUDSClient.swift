//
//  VPNControllerUDSClient.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import UDSHelper

public final class VPNControllerUDSClient {

    private let udsClient: UDSClient
    private let encoder = JSONEncoder()

    public init(udsClient: UDSClient) {
        self.udsClient = udsClient
    }
}

extension VPNControllerUDSClient: VPNControllerIPCClient {

    public func uninstall(_ component: VPNUninstallComponent) async throws {
        let payload = try encoder.encode(VPNIPCClientCommand.uninstall(component))
        try await udsClient.send(payload)
    }

    public func quit() async throws {
        let payload = try encoder.encode(VPNIPCClientCommand.quit)
        try await udsClient.send(payload)
    }
}
