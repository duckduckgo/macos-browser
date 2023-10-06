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

import Combine
import Foundation
import NetworkProtection
import NetworkProtectionIPC

final class TunnelControllerIPCServer {
    private let tunnelController: TunnelController
    private let server: NetworkProtectionIPC.TunnelControllerIPCServer
    private let statusReporter: NetworkProtectionStatusReporter
    private var cancellables = Set<AnyCancellable>()

    init(tunnelController: TunnelController, statusReporter: NetworkProtectionStatusReporter) {
        self.tunnelController = tunnelController
        server = .init(machServiceName: Bundle.main.bundleIdentifier!,
                       log: .networkProtectionIPCLog)
        self.statusReporter = statusReporter

        subscribeToStatusUpdates()
        subscribeToServerChanges()

        server.serverDelegate = self
    }

    public func activate() {
        server.activate()
    }

    private func subscribeToServerChanges() {
        statusReporter.serverInfoObserver.publisher
            .subscribe(on: DispatchQueue.main)
            .sink { [weak self] serverInfo in
                self?.server.serverInfoChanged(serverInfo)
            }
            .store(in: &cancellables)
    }

    private func subscribeToStatusUpdates() {
        statusReporter.statusObserver.publisher
            .subscribe(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.server.statusChanged(status)
            }
            .store(in: &cancellables)
    }
}

extension TunnelControllerIPCServer: IPCServerInterface {
    func register() {
        // TODO: consider adding support for this type of thing directly in the status reporter
        server.serverInfoChanged(statusReporter.serverInfoObserver.recentValue)
        server.statusChanged(statusReporter.statusObserver.recentValue)
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
