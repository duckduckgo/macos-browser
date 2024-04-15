//
//  XPCServer.swift
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

@objc
private class XPCConnectionsManager: NSObject, NSXPCListenerDelegate {

    private let clientInterface: NSXPCInterface
    private let serverInterface: NSXPCInterface
    fileprivate let queue: DispatchQueue
    weak var delegate: AnyObject?

    /// The active connections
    ///
    private(set) var connections = Set<NSXPCConnection>()

    init(clientInterface: NSXPCInterface,
         serverInterface: NSXPCInterface,
         queue: DispatchQueue = DispatchQueue(label: "com.duckduckgo.XPCConnectionsManager.queue")) {

        self.clientInterface = clientInterface
        self.serverInterface = serverInterface
        self.queue = queue
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {

        queue.sync {
            newConnection.exportedInterface = serverInterface
            newConnection.exportedObject = delegate
            newConnection.remoteObjectInterface = clientInterface

            let closeConnection = { [weak self, weak newConnection] in
                guard let self,
                      let newConnection else {
                    return
                }

                self.queue.async {
                    self.connections.remove(newConnection)
                }
            }

            newConnection.interruptionHandler = closeConnection
            newConnection.invalidationHandler = closeConnection
            connections.insert(newConnection)
            newConnection.activate()
        }

        return true
    }
}

/// An XPC server.
///
public final class XPCServer<ClientInterface: AnyObject, ServerInterface: AnyObject> {

    public enum ConnectionError: Error {
        case noRemoteObjectProxy
    }

    private let clientInterface: NSXPCInterface
    private let serverInterface: NSXPCInterface

    private let connectionsManager: XPCConnectionsManager

    /// The new-connections listener
    ///
    private let listener: NSXPCListener

    /// The delegate.
    ///
    public weak var delegate: ServerInterface? {
        get {
            connectionsManager.delegate as? ServerInterface
        }

        set {
            connectionsManager.delegate = newValue
        }
    }

    public init(machServiceName: String,
                clientInterface: NSXPCInterface,
                serverInterface: NSXPCInterface) {

        listener = NSXPCListener(machServiceName: machServiceName)
        self.clientInterface = clientInterface
        self.serverInterface = serverInterface

        connectionsManager = XPCConnectionsManager(clientInterface: clientInterface, serverInterface: serverInterface)

        listener.delegate = connectionsManager
    }

    deinit {
        listener.invalidate()
    }

    public func activate() {
        listener.activate()
    }
}

// MARK: - IPC Communication to the client

/// This extension implements the interface for sending IPC messages to all connected clients.
///
extension XPCServer {

    /// Returns a proxy for the client object.
    ///
    private func client(for connection: NSXPCConnection) throws -> ClientInterface {
        guard let client = connection.remoteObjectProxy as? ClientInterface else {
            throw ConnectionError.noRemoteObjectProxy
        }

        return client
    }

    public func forEachClient(do callback: @escaping (ClientInterface) -> Void) {
        connectionsManager.queue.async {
            for connection in self.connectionsManager.connections {
                let client: ClientInterface

                do {
                    client = try self.client(for: connection)
                } catch {
                    continue
                }

                callback(client)
            }
        }
    }
}
