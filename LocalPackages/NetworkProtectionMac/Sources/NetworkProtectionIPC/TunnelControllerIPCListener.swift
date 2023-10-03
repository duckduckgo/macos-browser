//
//  TunnelControllerIPCListener.swift
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
public final class TunnelControllerIPCListener: NSObject {

    typealias IPCClientInterface = TunnelControllerIPCClientInterface
    typealias IPCServerInterface = TunnelControllerIPCServerInterface

    /// The active connections
    ///
    private var connections = Set<NSXPCConnection>()

    /// The new-connections listener
    ///
    private let listener: NSXPCListener

    /// The actual server.
    ///
    public weak var server: TunnelControllerIPCServerInterface?

    public init(machServiceName: String, log: OSLog = .disabled) {

        self.listener = NSXPCListener(machServiceName: machServiceName)

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
extension TunnelControllerIPCListener: NSXPCListenerDelegate {
    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {

        newConnection.exportedInterface = NSXPCInterface(with: IPCServerInterface.self)
        newConnection.exportedObject = server
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
