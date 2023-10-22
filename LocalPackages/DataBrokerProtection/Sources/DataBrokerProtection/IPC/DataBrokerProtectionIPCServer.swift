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
import XPCHelper

/// This protocol describes the server-side IPC interface for controlling the tunnel
///
public protocol IPCServerInterface: AnyObject {
    /// Registers a connection with the server.
    ///
    /// This is the point where the server will start sending status updates to the client.
    ///
    func register()

    // MARK: - Scheduler

    /// Start the scheduler
    ///
    func startScheduler(showWebView: Bool)

    /// Stop the scheduler
    ///
    func stopScheduler()

    func optOutAllBrokers(showWebView: Bool, completion: @escaping ((Error?) -> Void))
    func scanAllBrokers(showWebView: Bool, completion: @escaping ((Error?) -> Void))
    func runQueuedOperations(showWebView: Bool, completion: @escaping ((Error?) -> Void))
    func runAllOperations(showWebView: Bool)
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

    // MARK: - Scheduler

    /// Start the scheduler
    ///
    func startScheduler(showWebView: Bool)

    /// Stop the scheduler
    ///
    func stopScheduler()

    func optOutAllBrokers(showWebView: Bool, completion: @escaping ((Error?) -> Void))
    func scanAllBrokers(showWebView: Bool, completion: @escaping ((Error?) -> Void))
    func runQueuedOperations(showWebView: Bool, completion: @escaping ((Error?) -> Void))
    func runAllOperations(showWebView: Bool)
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

    public func schedulerStatusChanges(_ status: DataBrokerProtectionSchedulerStatus) {
        let payload: Data

        do {
            payload = try JSONEncoder().encode(status)
        } catch {
            return
        }

        xpc.forEachClient { client in
            client.schedulerStatusChanged(payload)
        }
    }
}

// MARK: - Incoming communication from a client

extension DataBrokerProtectionIPCServer: XPCServerInterface {
    func register() {
        serverDelegate?.register()
    }

    func startScheduler(showWebView: Bool) {
        serverDelegate?.startScheduler(showWebView: showWebView)
    }

    func stopScheduler() {
        serverDelegate?.stopScheduler()
    }

    func optOutAllBrokers(showWebView: Bool, completion: @escaping ((Error?) -> Void)) {
        serverDelegate?.optOutAllBrokers(showWebView: showWebView, completion: completion)
    }

    func scanAllBrokers(showWebView: Bool, completion: @escaping ((Error?) -> Void)) {
        serverDelegate?.scanAllBrokers(showWebView: showWebView, completion: completion)
    }

    func runQueuedOperations(showWebView: Bool, completion: @escaping ((Error?) -> Void)) {
        serverDelegate?.runQueuedOperations(showWebView: showWebView, completion: completion)
    }

    func runAllOperations(showWebView: Bool) {
        serverDelegate?.runAllOperations(showWebView: showWebView)
    }
}
