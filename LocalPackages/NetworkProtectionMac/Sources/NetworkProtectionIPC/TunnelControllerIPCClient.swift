//
//  TunnelControllerIPCClient.swift
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
public protocol IPCClientInterface: AnyObject {
    func errorChanged(_ error: String?)
    func serverInfoChanged(_ serverInfo: NetworkProtectionStatusServerInfo)
    func statusChanged(_ status: ConnectionStatus)
}

/// This is the XPC interface with parameters that can be packed properly
@objc
protocol XPCClientInterface {
    func errorChanged(error: String?)
    func serverInfoChanged(payload: Data)
    func statusChanged(payload: Data)
}

public final class TunnelControllerIPCClient {

    // MARK: - XPC Communication

    let xpc: XPCClient<XPCClientInterface, XPCServerInterface>

    // MARK: - Observers offered

    public var serverInfoObserver = ConnectionServerInfoObserverThroughIPC()
    public var connectionErrorObserver = ConnectionErrorObserverThroughIPC()
    public var connectionStatusObserver = ConnectionStatusObserverThroughIPC()

    /// The delegate.
    ///
    public weak var clientDelegate: IPCClientInterface? {
        didSet {
            xpcDelegate.clientDelegate = self.clientDelegate
        }
    }

    private let xpcDelegate: TunnelControllerXPCClientDelegate

    public init(machServiceName: String) {
        let clientInterface = NSXPCInterface(with: XPCClientInterface.self)
        let serverInterface = NSXPCInterface(with: XPCServerInterface.self)
        self.xpcDelegate = TunnelControllerXPCClientDelegate(
            clientDelegate: self.clientDelegate,
            serverInfoObserver: self.serverInfoObserver,
            connectionErrorObserver: self.connectionErrorObserver,
            connectionStatusObserver: self.connectionStatusObserver
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
                self.register()
            }
        }

        self.register()
    }
}

private final class TunnelControllerXPCClientDelegate: XPCClientInterface {

    weak var clientDelegate: IPCClientInterface?
    let serverInfoObserver: ConnectionServerInfoObserverThroughIPC
    let connectionErrorObserver: ConnectionErrorObserverThroughIPC
    let connectionStatusObserver: ConnectionStatusObserverThroughIPC

    init(clientDelegate: IPCClientInterface?,
         serverInfoObserver: ConnectionServerInfoObserverThroughIPC,
         connectionErrorObserver: ConnectionErrorObserverThroughIPC,
         connectionStatusObserver: ConnectionStatusObserverThroughIPC) {
        self.clientDelegate = clientDelegate
        self.serverInfoObserver = serverInfoObserver
        self.connectionErrorObserver = connectionErrorObserver
        self.connectionStatusObserver = connectionStatusObserver
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

        connectionStatusObserver.publish(status)
        clientDelegate?.statusChanged(status)
    }
}

// MARK: - Outgoing communication to the server

extension TunnelControllerIPCClient: IPCServerInterface {
    public func register() {
        xpc.execute(call: { server in
            server.register()
        }, xpcReplyErrorHandler: { _ in
            // Intentional no-op as there's no completion block
            // If you add a completion block, please remember to call it here too!
        })
    }

    public func start(completion: @escaping (Error?) -> Void) {
        xpc.execute(call: { server in
            server.start(completion: completion)
        }, xpcReplyErrorHandler: completion)
    }

    public func stop(completion: @escaping (Error?) -> Void) {
        xpc.execute(call: { server in
            server.stop(completion: completion)
        }, xpcReplyErrorHandler: completion)
    }

    public func debugCommand(_ command: DebugCommand) async throws {
        guard let payload = try? JSONEncoder().encode(command) else {
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            xpc.execute(call: { server in
                server.debugCommand(payload) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }, xpcReplyErrorHandler: { error in
                // Intentional no-op as there's no completion block
                // If you add a completion block, please remember to call it here too!
                continuation.resume(throwing: error)
            })
        }
    }
}
