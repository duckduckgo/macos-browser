//
//  NetPPopoverManagerMock.swift
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

#if DEBUG && NETWORK_PROTECTION

import Combine
import Foundation
import NetworkProtection

final class NetPPopoverManagerMock: NetPPopoverManager {
    var isShown: Bool { false }
    var ipcClient: NetworkProtectionIPCClient = IPCClientMock()

    func toggle(positionedBelow view: NSView, withDelegate delegate: NSPopoverDelegate) {}
    func show(positionedBelow view: NSView, withDelegate delegate: any NSPopoverDelegate) {}
    func close() {}
}

final class IPCClientMock: NetworkProtectionIPCClient {

    final class ConnectionStatusObserverMock: NetworkProtection.ConnectionStatusObserver {
        var publisher: AnyPublisher<NetworkProtection.ConnectionStatus, Never> = PassthroughSubject().eraseToAnyPublisher()
        var recentValue: NetworkProtection.ConnectionStatus = .notConfigured
    }
    var ipcStatusObserver: any NetworkProtection.ConnectionStatusObserver = ConnectionStatusObserverMock()

    final class ConnectionServerInfoObserverMock: NetworkProtection.ConnectionServerInfoObserver {
        var publisher: AnyPublisher<NetworkProtection.NetworkProtectionStatusServerInfo, Never> = PassthroughSubject().eraseToAnyPublisher()
        var recentValue: NetworkProtection.NetworkProtectionStatusServerInfo = .unknown
    }
    var ipcServerInfoObserver: any NetworkProtection.ConnectionServerInfoObserver = ConnectionServerInfoObserverMock()

    final class ConnectionErrorObserverMock: NetworkProtection.ConnectionErrorObserver {
        var publisher: AnyPublisher<String?, Never> = PassthroughSubject().eraseToAnyPublisher()
        var recentValue: String?
    }
    var ipcConnectionErrorObserver: any NetworkProtection.ConnectionErrorObserver = ConnectionErrorObserverMock()

    final class ConnectivityIssueObserverMock: NetworkProtection.ConnectivityIssueObserver {
        var publisher: AnyPublisher<Bool, Never> = PassthroughSubject().eraseToAnyPublisher()
        var recentValue: Bool = false
    }
    var ipcConnectivityIssuesObserver: any NetworkProtection.ConnectivityIssueObserver = ConnectivityIssueObserverMock()

    final class ControllerErrorMesssageObserverMock: NetworkProtection.ControllerErrorMesssageObserver {
        var publisher: AnyPublisher<String?, Never> = PassthroughSubject().eraseToAnyPublisher()
        var recentValue: String?
    }
    var ipcControllerErrorMessageObserver: any NetworkProtection.ControllerErrorMesssageObserver = ControllerErrorMesssageObserverMock()

    func start() {}

    func stop() {}

}

final class ConnectivityIssueObserverMock: ConnectivityIssueObserver {
    var publisher: AnyPublisher<Bool, Never> = PassthroughSubject().eraseToAnyPublisher()
    var recentValue = false
}

final class ControllerErrorMesssageObserverMock: ControllerErrorMesssageObserver {
    var publisher: AnyPublisher<String?, Never> = PassthroughSubject().eraseToAnyPublisher()
    var recentValue: String?
}

#endif
