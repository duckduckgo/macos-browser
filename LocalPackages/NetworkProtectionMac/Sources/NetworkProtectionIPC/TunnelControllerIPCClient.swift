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
    public weak var clientDelegate: IPCClientInterface?

    public init(machServiceName: String) {
        let clientInterface = NSXPCInterface(with: XPCClientInterface.self)
        let serverInterface = NSXPCInterface(with: XPCServerInterface.self)

        xpc = XPCClient(
            machServiceName: machServiceName,
            clientInterface: clientInterface,
            serverInterface: serverInterface)

        xpc.delegate = self
    }
}

// MARK: - Outgoing communication to the server

extension TunnelControllerIPCClient: IPCServerInterface {    
    public func register() {
        try? xpc.server().register()
    }

    public func start() {
        try? xpc.server().start()
    }

    public func stop() {
        try? xpc.server().stop()
    }

    public func resetAll(uninstallSystemExtension: Bool) async {
        try? await xpc.server().resetAll(uninstallSystemExtension: uninstallSystemExtension)
    }

    public func debugCommand(_ command: DebugCommand) async {
        guard let payload = try? JSONEncoder().encode(command) else {
            return
        }

        try? await xpc.server().debugCommand(payload)
    }
}

// MARK: - Incoming communication from the server

extension TunnelControllerIPCClient: XPCClientInterface {

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
