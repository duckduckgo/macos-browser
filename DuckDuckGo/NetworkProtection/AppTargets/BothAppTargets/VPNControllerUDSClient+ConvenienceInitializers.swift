//
//  VPNControllerUDSClient+ConvenienceInitializers.swift
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
import NetworkProtectionIPC
import UDSHelper

extension VPNControllerUDSClient {
    convenience init(fileManager: FileManager = .default, bundle: Bundle = .main) {
        let socketFileURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: bundle.appGroup(bundle: .ipc))!.appendingPathComponent("vpn.ipc")

        let udsClient = UDSClient<VPNIPCClientCommand, VPNIPCServerCommand>(socketFileURL: socketFileURL, log: .networkProtectionIPCLog)

        self.init(udsClient: udsClient)
    }
}
