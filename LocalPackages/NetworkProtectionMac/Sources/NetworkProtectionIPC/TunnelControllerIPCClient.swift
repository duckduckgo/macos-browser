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
protocol XPCClientInterface: NSObjectProtocol {
    func errorChanged(error: String?)
    func serverInfoChanged(payload: Data)
    func statusChanged(payload: Data)
}

public final class TunnelControllerIPCClient: NSObject {

    // MARK: - XPC Communication

    let xpc: XPCClient<XPCClientInterface, XPCServerInterface>

    // MARK: - Observers offered

    public var serverInfoObserver = ConnectionServerInfoObserverThroughIPC()
    public var connectionErrorObserver = ConnectionErrorObserverThroughIPC()
    public var connectionStatusObserver = ConnectionStatusObserverThroughIPC()

    /// The delegate.
    ///
    public weak var clientDelegate: IPCClientInterface?

    public init(machServiceName: String) {
        let clientInterface = NSXPCInterface(with: XPCClientInterface.self)
        let serverInterface = NSXPCInterface(with: XPCServerInterface.self)

        xpc = XPCClient(
            machServiceName: machServiceName,
            clientInterface: clientInterface,
            serverInterface: serverInterface)

<<<<<<< HEAD
<<<<<<< HEAD
        xpc.delegate = xpcDelegate
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
=======
        super.init()

        xpc.delegate = self
    }
}

=======
        super.init()

        xpc.delegate = self
    }
}

>>>>>>> d68434899 (Revert "Merge tag '1.71.0'")
// MARK: - Incoming communication from the server

extension TunnelControllerIPCClient: XPCClientInterface {
>>>>>>> 475a09282 (Fix IPC memory leak (DBP support) (#2092))

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
<<<<<<< HEAD

=======
>>>>>>> 475a09282 (Fix IPC memory leak (DBP support) (#2092))
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

    public func start() {
        xpc.execute(call: { server in
            server.start()
        }, xpcReplyErrorHandler: { _ in
            // Intentional no-op as there's no completion block
            // If you add a completion block, please remember to call it here too!
        })
    }

    public func stop() {
        xpc.execute(call: { server in
            server.stop()
        }, xpcReplyErrorHandler: { _ in
            // Intentional no-op as there's no completion block
            // If you add a completion block, please remember to call it here too!
        })
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
