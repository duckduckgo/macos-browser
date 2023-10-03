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
import os.log

/// This protocol describes the client-side IPC interface for controlling the tunnel
///
@objc
public protocol TunnelControllerIPCClientInterface {

}

/// An IPC client for controlling the tunnel
///
public final class TunnelControllerIPCClient {

    typealias IPCClientInterface = TunnelControllerIPCClientInterface
    typealias IPCServerInterface = TunnelControllerIPCServerInterface

    public enum ConnectionError: Error {
        case noRemoteObjectProxy
    }

    private let machServiceName: String

    /// The internal connection, which may still not have been created.
    ///
    private var internalConnection: NSXPCConnection?

    /// A convenience to access the existing connection or make a new one if it doesn't already exist.
    ///
    private var connection: NSXPCConnection {
        guard let internalConnection else {
            let newConnection = makeConnection()
            internalConnection = newConnection
            return newConnection
        }

        return internalConnection
    }

    public init(machServiceName: String, log: OSLog = .disabled) {
        self.machServiceName = machServiceName
    }

    deinit {
        internalConnection?.invalidate()
    }

    /// Make a new connection
    ///
    private func makeConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(machServiceName: machServiceName)
        connection.exportedInterface = NSXPCInterface(with: IPCClientInterface.self)
        connection.exportedObject = self
        connection.remoteObjectInterface = NSXPCInterface(with: IPCServerInterface.self)

        let closeConnection = {
            [weak self] in
               guard let self else {
                   return
               }

               self.internalConnection = nil
        }

        connection.interruptionHandler = closeConnection
        connection.invalidationHandler = closeConnection
        connection.activate()

        return connection
    }

    /// Returns a proxy for the server object.
    ///
    /// It's important to not store the object returned by this method, because calling this method ensures a
    /// normalized handling of connection issues and reconnection logic.
    ///
    func serverProxy(attemptCount: Int = 0) throws -> TunnelControllerIPCServerInterface {
        guard let proxy = connection.remoteObjectProxy as? TunnelControllerIPCServerInterface else {
            throw ConnectionError.noRemoteObjectProxy
        }

        return proxy
    }
}

// MARK: - Server communication

/// This extension implements the IPC client interface
///
extension TunnelControllerIPCClient {
    public func start(completion: (Bool) -> Void) {
        let serverProxy: TunnelControllerIPCServerInterface

        do {
            serverProxy = try self.serverProxy()
        } catch {
            completion(false)
            return
        }

        serverProxy.start()
        completion(true)
    }

    public func stop() async throws {
        let serverProxy = try serverProxy()
        serverProxy.stop()
    }
}

// MARK: - TunnelControllerIPCClientInterface

/// This extension implements the IPC client interface
///
extension TunnelControllerIPCClient: TunnelControllerIPCClientInterface {

}
