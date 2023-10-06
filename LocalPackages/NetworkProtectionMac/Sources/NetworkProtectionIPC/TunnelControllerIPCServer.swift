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
import Intercom
import NetworkProtection
import os.log // swiftlint:disable:this enforce_os_log_wrapper

/// This protocol describes the server-side IPC interface for controlling the tunnel
///
public protocol TunnelControllerIPCServerInterface: AnyObject {
    /// Registers a connection with the server.
    ///
    /// This is the point where the server will start sending status updates to the client.
    ///
    func register()

    /// Start the VPN tunnel.
    ///
    func start()

    /// Stop the VPN tunnel.
    ///
    func stop()
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

    /// Start the VPN tunnel.
    ///
    func start()

    /// Stop the VPN tunnel.
    ///
    func stop()
}

public final class TunnelControllerIPCServer {
    let xpc: XPCServer<XPCClientInterface, XPCServerInterface>

    /// The delegate.
    ///
    public weak var serverDelegate: TunnelControllerIPCServerInterface?

    public init(machServiceName: String, log: OSLog = .disabled) {
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

extension TunnelControllerIPCServer: TunnelControllerIPCClientInterface {

    public func serverInfoChanged(_ serverInfo: NetworkProtectionStatusServerInfo) {
        let payload: Data

        do {
            payload = try JSONEncoder().encode(serverInfo)
        } catch {
            //os_log("statusChanged failed to encode JSON payload", log: log, type: .error)
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
            //os_log("statusChanged failed to encode JSON payload", log: log, type: .error)
            return
        }

        xpc.forEachClient { client in
            client.statusChanged(payload: payload)
        }
    }
}

// MARK: - Incoming communication from a client

extension TunnelControllerIPCServer: XPCServerInterface {
    func register() {
        serverDelegate?.register()
    }

    func start() {
        serverDelegate?.start()
    }

    func stop() {
        serverDelegate?.stop()
    }
}
