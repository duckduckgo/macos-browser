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

#if DEBUG

import AppKit
import Combine
import Foundation
import NetworkProtection

final class NetPPopoverManagerMock: NetPPopoverManager {
    var isShown: Bool { false }
    var ipcClient: NetworkProtectionIPCClient = IPCClientMock()

    func toggle(positionedBelow view: NSView, withDelegate delegate: NSPopoverDelegate) -> NSPopover? {
        return nil
    }
    func show(positionedBelow view: NSView, withDelegate delegate: any NSPopoverDelegate) -> NSPopover {
        return NSPopover()
    }
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

    final class DataVolumeObserverMock: NetworkProtection.DataVolumeObserver {
        var publisher: AnyPublisher<DataVolume, Never> = PassthroughSubject().eraseToAnyPublisher()
        var recentValue: DataVolume = .init()
    }
    var ipcDataVolumeObserver: any NetworkProtection.DataVolumeObserver = DataVolumeObserverMock()

    final class KnownFailureObserverMock: NetworkProtection.KnownFailureObserver {
        var publisher: AnyPublisher<KnownFailure?, Never> = PassthroughSubject().eraseToAnyPublisher()
        var recentValue: KnownFailure?
    }
    var ipcKnownFailureObserver: any NetworkProtection.KnownFailureObserver = KnownFailureObserverMock()

    func start(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    func stop(completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    func command(_ command: VPNCommand) async throws {
        return
    }

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
