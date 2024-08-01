//
//  VPNControllerXPCClient.swift
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
import XPCHelper

/// This protocol describes the client-side IPC interface for controlling the tunnel
///
public protocol XPCClientInterface: AnyObject {
    func errorChanged(_ error: String?)
    func serverInfoChanged(_ serverInfo: NetworkProtectionStatusServerInfo)
    func statusChanged(_ status: ConnectionStatus)
    func dataVolumeUpdated(_ dataVolume: DataVolume)
    func knownFailureUpdated(_ failure: KnownFailure?)
}

/// This is the XPC interface with parameters that can be packed properly
@objc
protocol XPCClientInterfaceObjC {
    func errorChanged(error: String?)
    func serverInfoChanged(payload: Data)
    func statusChanged(payload: Data)
    func dataVolumeUpdated(payload: Data)
    func knownFailureUpdated(payload: Data)
}

public final class VPNControllerXPCClient {

    // MARK: - XPC Communication

    let xpc: XPCClient<XPCClientInterfaceObjC, XPCServerInterfaceObjC>

    // MARK: - Observers offered

    public var serverInfoObserver = ConnectionServerInfoObserverThroughIPC()
    public var connectionErrorObserver = ConnectionErrorObserverThroughIPC()
    public var connectionStatusObserver = ConnectionStatusObserverThroughIPC()
    public var dataVolumeObserver = DataVolumeObserverThroughIPC()
    public var knownFailureObserver = KnownFailureObserverThroughIPC()

    /// The delegate.
    ///
    public weak var clientDelegate: XPCClientInterface? {
        didSet {
            xpcDelegate.clientDelegate = self.clientDelegate
        }
    }

    private let xpcDelegate: TunnelControllerXPCClientDelegate

    public init(machServiceName: String) {
        let clientInterface = NSXPCInterface(with: XPCClientInterfaceObjC.self)
        let serverInterface = NSXPCInterface(with: XPCServerInterfaceObjC.self)
        self.xpcDelegate = TunnelControllerXPCClientDelegate(
            clientDelegate: self.clientDelegate,
            serverInfoObserver: self.serverInfoObserver,
            connectionErrorObserver: self.connectionErrorObserver,
            connectionStatusObserver: self.connectionStatusObserver,
            dataVolumeObserver: self.dataVolumeObserver,
            knownFailureObserver: self.knownFailureObserver
        )

        xpc = XPCClient(
            machServiceName: machServiceName,
            clientInterface: clientInterface,
            serverInterface: serverInterface)

        xpc.delegate = xpcDelegate
        xpc.onDisconnect = { [weak self] in
            guard let self else { return }

            Task { @MainActor in
                try await Task.sleep(interval: .seconds(1))

                // By calling register we make sure that XPC will connect as soon as it
                // becomes available again, as requests are queued.  This helps ensure
                // that the client app will always be connected to XPC.
                self.register { _ in }
            }
        }

        self.register { _ in }
    }

    /// Forces the XPC client status to be updated to disconnected.
    ///
    /// This is just used as a temporary mechanism to allow the main app to tell that the VPN has been disconnected
    /// when it's uninstalled.  You should not call this method directly or rely on this for other logic.  This should be
    /// replaced by status updates through XPC.
    ///
    public func forceStatusToDisconnected() {
        xpcDelegate.statusChanged(status: .disconnected)
    }
}

private final class TunnelControllerXPCClientDelegate: XPCClientInterfaceObjC {

    weak var clientDelegate: XPCClientInterface?
    let serverInfoObserver: ConnectionServerInfoObserverThroughIPC
    let connectionErrorObserver: ConnectionErrorObserverThroughIPC
    let connectionStatusObserver: ConnectionStatusObserverThroughIPC
    let dataVolumeObserver: DataVolumeObserverThroughIPC
    let knownFailureObserver: KnownFailureObserverThroughIPC

    init(clientDelegate: XPCClientInterface?,
         serverInfoObserver: ConnectionServerInfoObserverThroughIPC,
         connectionErrorObserver: ConnectionErrorObserverThroughIPC,
         connectionStatusObserver: ConnectionStatusObserverThroughIPC,
         dataVolumeObserver: DataVolumeObserverThroughIPC,
         knownFailureObserver: KnownFailureObserverThroughIPC) {
        self.clientDelegate = clientDelegate
        self.serverInfoObserver = serverInfoObserver
        self.connectionErrorObserver = connectionErrorObserver
        self.connectionStatusObserver = connectionStatusObserver
        self.dataVolumeObserver = dataVolumeObserver
        self.knownFailureObserver = knownFailureObserver
    }

    func errorChanged(error: String?) {
        connectionErrorObserver.publish(error)
        clientDelegate?.errorChanged(error)
    }

    func serverInfoChanged(payload: Data) {
        guard let serverInfo = try? JSONDecoder().decode(NetworkProtectionStatusServerInfo.self, from: payload) else {
            return
        }

        serverInfoObserver.publish(serverInfo)
        clientDelegate?.serverInfoChanged(serverInfo)
    }

    func statusChanged(payload: Data) {
        guard let status = try? JSONDecoder().decode(ConnectionStatus.self, from: payload) else {
            return
        }

        statusChanged(status: status)
    }

    func statusChanged(status: ConnectionStatus) {
        connectionStatusObserver.publish(status)
        clientDelegate?.statusChanged(status)
    }

    func dataVolumeUpdated(payload: Data) {
        guard let dataVolume = try? JSONDecoder().decode(DataVolume.self, from: payload) else {
            return
        }

        dataVolumeObserver.publish(dataVolume)
        clientDelegate?.dataVolumeUpdated(dataVolume)
    }

    func knownFailureUpdated(payload: Data) {
        guard let failure = try? JSONDecoder().decode(KnownFailure?.self, from: payload) else {
            return
        }

        knownFailureUpdated(failure: failure)
    }

    func knownFailureUpdated(failure: KnownFailure?) {
        knownFailureObserver.publish(failure)
        clientDelegate?.knownFailureUpdated(failure)
    }
}

// MARK: - Outgoing communication to the server

extension VPNControllerXPCClient: XPCServerInterface {

    public func register(completion: @escaping (Error?) -> Void) {
        register(version: version, bundlePath: bundlePath, completion: self.onComplete(completion))
    }

    public func register(version: String, bundlePath: String, completion: @escaping (Error?) -> Void) {
        xpc.execute(call: { server in
            server.register(version: version, bundlePath: bundlePath, completion: self.onComplete(completion))
        }, xpcReplyErrorHandler: self.onComplete(completion))
    }

    public func onComplete(_ completion: @escaping (Error?) -> Void) -> (Error?) -> Void {
        { [weak self] error in
            self?.xpcDelegate.knownFailureUpdated(failure: .init(error))
            completion(error)
        }
    }

    public func start(completion: @escaping (Error?) -> Void) {
        xpc.execute(call: { server in
            server.start(completion: self.onComplete(completion))
        }, xpcReplyErrorHandler: self.onComplete(completion))
    }

    public func stop(completion: @escaping (Error?) -> Void) {
        xpc.execute(call: { server in
            server.stop(completion: self.onComplete(completion))
        }, xpcReplyErrorHandler: self.onComplete(completion))
    }

    public func fetchLastError(completion: @escaping (Error?) -> Void) {
        xpc.execute(call: { server in
            server.fetchLastError(completion: completion)
        }, xpcReplyErrorHandler: completion)
    }

    public func command(_ command: VPNCommand) async throws {
        guard let payload = try? JSONEncoder().encode(command) else {
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            xpc.execute(call: { server in
                server.command(payload) { [weak self] error in
                    if let error {
                        self?.xpcDelegate.knownFailureUpdated(failure: .init(error))
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }, xpcReplyErrorHandler: { [weak self] error in
                self?.xpcDelegate.knownFailureUpdated(failure: .init(error))
                continuation.resume(throwing: error)
            })
        }
    }
}

extension VPNControllerXPCClient: VPNControllerIPCClient {

    public func uninstall(_ component: VPNUninstallComponent) async throws {
        switch component {
        case .all:
            try await self.command(.uninstallVPN)
        case .configuration:
            try await self.command(.removeVPNConfiguration)
        case .systemExtension:
            try await self.command(.removeSystemExtension)
        }
    }

    public func quit() async throws {
        try await self.command(.removeSystemExtension)
    }
}
