//
//  XPCClient.swift
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

/// An XPC client
///
public final class XPCClient<ClientInterface: AnyObject, ServerInterface: AnyObject> {

    public enum ConnectionError: Error {
        case noRemoteObjectProxy
    }

    private let machServiceName: String
    private let clientInterface: NSXPCInterface
    private let serverInterface: NSXPCInterface

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

    /// The delegate.
    ///
    public weak var delegate: ClientInterface? {
        didSet {
            connection.exportedObject = delegate
        }
    }

    // MARK: - Initialization

    public init(machServiceName: String,
                clientInterface: NSXPCInterface,
                serverInterface: NSXPCInterface) {

        self.machServiceName = machServiceName
        self.clientInterface = clientInterface
        self.serverInterface = serverInterface
    }

    deinit {
        internalConnection?.invalidate()
    }

    /// Make a new connection
    ///
    private func makeConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(machServiceName: machServiceName)
        connection.exportedInterface = clientInterface
        connection.exportedObject = delegate
        connection.remoteObjectInterface = serverInterface

        let closeConnection = { [weak self] in
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
    public func server() throws -> ServerInterface {
        guard let server = connection.remoteObjectProxy as? ServerInterface else {
            throw ConnectionError.noRemoteObjectProxy
        }

        return server
    }
}
