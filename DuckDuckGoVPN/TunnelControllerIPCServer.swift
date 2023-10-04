//
//  TunnelControllerIPCServer.swift
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
import NetworkProtection
import NetworkProtectionIPC

final class TunnelControllerIPCServer {
    private let tunnelController: TunnelController
    private let server: NetworkProtectionIPC.TunnelControllerIPCServer

    init(tunnelController: TunnelController) {
        self.tunnelController = tunnelController
        server = .init(machServiceName: Bundle.main.bundleIdentifier!,
                       log: .networkProtectionIPCLog)

        server.delegate = self
    }

    public func activate() {
        server.activate()
    }
}

extension TunnelControllerIPCServer: TunnelControllerIPCServerInterface {
    func register(completion: (Error) -> Void) {
        completion(NSError(domain: "vpn", code: 0))
    }

    func start() {
        Task {
            await tunnelController.start()
        }
    }

    func stop() {
        Task {
            await tunnelController.stop()
        }
    }
}
