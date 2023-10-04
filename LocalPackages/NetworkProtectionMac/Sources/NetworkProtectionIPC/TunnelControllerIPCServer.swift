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
import os.log // swiftlint:disable:this enforce_os_log_wrapper

/// This protocol describes the server-side IPC interface for controlling the tunnel
///
@objc
public protocol TunnelControllerIPCServerInterface {
    func start()
    func stop()
}

/// An IPC client for controlling the tunnel
///
@objc
public final class TunnelControllerIPCServer: NSObject {

    typealias IPCClientInterface = TunnelControllerIPCClientInterface
    typealias IPCServerInterface = TunnelControllerIPCServerInterface

    public enum ConnectionError: Error {
        case noRemoteObjectProxy
    }

    /// The active connections
    ///
    private var connections = Set<NSXPCConnection>()

    /// The new-connections listener
    ///
    private let listener: NSXPCListener

    private let log: OSLog

    /// The delegate.
    ///
    public weak var delegate: TunnelControllerIPCServerInterface?

    public init(machServiceName: String, log: OSLog = .disabled) {

        self.listener = NSXPCListener(machServiceName: machServiceName)
        self.log = log

        super.init()

        listener.delegate = self
    }

    deinit {
        listener.invalidate()
    }

    public func activate() {
        listener.activate()
    }
}

// MARK: - NSXPCListenerDelegate

/// This extension implements listening for new connections through our NSXPCListener
///
extension TunnelControllerIPCServer: NSXPCListenerDelegate {
    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {

        newConnection.exportedInterface = NSXPCInterface(with: IPCServerInterface.self)
        newConnection.exportedObject = delegate
        newConnection.remoteObjectInterface = NSXPCInterface(with: IPCClientInterface.self)

        let closeConnection = { [weak self, weak newConnection] in
           guard let self,
                 let newConnection else {
               return
           }

           self.connections.remove(newConnection)
        }

        newConnection.interruptionHandler = closeConnection
        newConnection.invalidationHandler = closeConnection
        connections.insert(newConnection)
        newConnection.activate()

        return true
    }
}

// MARK: - IPC Communication to the client

/// This extension implements the interface for sending IPC messages to all connected clients.
///
extension TunnelControllerIPCServer {

    /// Returns a proxy for the client object.
    ///
    private func proxy(for connection: NSXPCConnection) throws -> TunnelControllerIPCClientInterface {
        guard let proxy = connection.remoteObjectProxy as? TunnelControllerIPCClientInterface else {
            throw ConnectionError.noRemoteObjectProxy
        }

        return proxy
    }

    private func forEachProxy(do callback: @escaping (TunnelControllerIPCClientInterface) -> Void) {
        for connection in connections {
            let proxy: TunnelControllerIPCClientInterface

            do {
                proxy = try self.proxy(for: connection)
            } catch {
                os_log("statusChanged failed to encode JSON payload", log: log, type: .error)
                continue
            }

            callback(proxy)
        }
    }

    /// Sends a statusChanged IPC message to all connections, through the proxy objects.
    ///
    public func statusChanged(newStatus: ConnectionStatus) {
        let payload: Data

        do {
            payload = try JSONEncoder().encode(newStatus)
        } catch {
            os_log("statusChanged failed to encode JSON payload", log: log, type: .error)
            return
        }

        forEachProxy { proxy in
            proxy.statusChanged(payload: payload)
        }
    }
}
