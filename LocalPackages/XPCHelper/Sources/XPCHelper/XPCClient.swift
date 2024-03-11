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

/// This actor is meant to support synchronized access to the XPC connection
///
@globalActor
private struct XPCConnectionActor {
    actor ActorType { }

    static let shared: ActorType = ActorType()
}

/// An XPC client
///
public final class XPCClient<ClientInterface: AnyObject, ServerInterface: AnyObject> {

    public enum ConnectionError: Error {
        case noRemoteObjectProxy
    }

    private let machServiceName: String
    private let clientInterface: NSXPCInterface
    private let serverInterface: NSXPCInterface
    public var onDisconnect: (() -> Void)?

    /// The internal connection, which may still not have been created.
    ///
    @XPCConnectionActor
    private var internalConnection: NSXPCConnection?

    /// A convenience to access the existing connection or make a new one if it doesn't already exist.
    ///
    @XPCConnectionActor
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
            Task { @XPCConnectionActor in
                connection.exportedObject = delegate
            }
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

            Task { @XPCConnectionActor in
                self.internalConnection?.invalidate()
                self.internalConnection = nil
                self.onDisconnect?()
            }
        }

        connection.interruptionHandler = closeConnection
        connection.invalidationHandler = closeConnection
        connection.activate()

        return connection
    }

    public func execute(call: @escaping (ServerInterface) -> Void, xpcReplyErrorHandler: @escaping (Error) -> Void) {
        Task { @XPCConnectionActor in
            guard let serverInterface = connection.remoteObjectProxyWithErrorHandler({ error in
                // This will be called if there's an error while waiting for an XPC response.
                // Ref: https://developer.apple.com/documentation/foundation/nsxpcproxycreating/1415611-remoteobjectproxywitherrorhandle
                //
                // Since when there's an error while waiting for a response a completion callback will not be called, this
                // allows us to call the completion callback ourselves.
                xpcReplyErrorHandler(error)
            }) as? ServerInterface else {
                // This won't collide with the error handling above, as if this error happens there won't be any XPC
                // request to begin with.
                xpcReplyErrorHandler(ConnectionError.noRemoteObjectProxy)
                return
            }

            call(serverInterface)
        }
    }
}
