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
import XPCHelper

/// This protocol describes the server-side IPC interface for controlling the tunnel
///
public protocol IPCServerInterface: AnyObject {
    /// Registers a connection with the server.
    ///
    /// This is the point where the server will start sending status updates to the client.
    ///
    func register()

    /// Start the scheduler
    ///
    func start()

    /// Stop the scheduler
    ///
    func stop()

    /// Restart the scheduler
    ///
    func restart()
}

/// This protocol describes the server-side XPC interface.
///
/// The object that implements this interface takes care of unpacking any encoded data and forwarding
/// calls to the IPC interface when appropriate.
///
@objc
protocol XPCServerInterface {
    /// Registers a connection with the server.
    ///
    /// This is the point where the server will start sending status updates to the client.
    ///
    func register()

    /// Start the scheduler
    ///
    func start()

    /// Stop the scheduler
    ///
    func stop()

    /// Restart the scheduler
    ///
    func restart()
}

public final class DataBrokerProtectionIPCServer {
    let xpc: XPCServer<XPCClientInterface, XPCServerInterface>

    /// The delegate.
    ///
    public weak var serverDelegate: IPCServerInterface?

    public init(machServiceName: String) {
        let clientInterface = NSXPCInterface(with: XPCClientInterface.self)
        let serverInterface = NSXPCInterface(with: XPCServerInterface.self)

        xpc = XPCServer(
            machServiceName: machServiceName,
            clientInterface: clientInterface,
            serverInterface: serverInterface)

        xpc.delegate = self
    }

    public func activate() {
        xpc.activate()
    }
}

// MARK: - Outgoing communication to the clients

extension DataBrokerProtectionIPCServer: IPCClientInterface {
/*
    public func errorChanged(_ error: String?) {
        xpc.forEachClient { client in
            client.errorChanged(error: error)
        }
    }

    public func serverInfoChanged(_ serverInfo: NetworkProtectionStatusServerInfo) {
        let payload: Data

        do {
            payload = try JSONEncoder().encode(serverInfo)
        } catch {
            return
        }

        xpc.forEachClient { client in
            client.serverInfoChanged(payload: payload)
        }
    }

    /// Sends a statusChanged IPC message to all connections, through the proxy objects.
    ///
    public func statusChanged(_ status: ConnectionStatus) {
        let payload: Data

        do {
            payload = try JSONEncoder().encode(status)
        } catch {
            return
        }

        xpc.forEachClient { client in
            client.statusChanged(payload: payload)
        }
    }*/
}

// MARK: - Incoming communication from a client

extension DataBrokerProtectionIPCServer: XPCServerInterface {
    func register() {
        serverDelegate?.register()
    }

    func start() {
        serverDelegate?.start()
    }

    func stop() {
        serverDelegate?.stop()
    }

    func restart() {
        serverDelegate?.restart()
    }
}
