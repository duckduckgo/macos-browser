//
//  DataBrokerProtectionIPCClient.swift
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

import Combine
import Foundation
import XPCHelper

/// This protocol describes the server-side IPC interface for controlling the tunnel
///
public protocol IPCClientInterface: AnyObject {
    func schedulerStatusChanges(_ status: DataBrokerProtectionSchedulerStatus)
}

/// This is the XPC interface with parameters that can be packed properly
@objc
protocol XPCClientInterface {
    func schedulerStatusChanged(_ payload: Data)
}

public final class DataBrokerProtectionIPCClient {

    // MARK: - XPC Communication

    let xpc: XPCClient<XPCClientInterface, XPCServerInterface>

    // MARK: - Scheduler Status

    @Published
    private(set) public var schedulerStatus: DataBrokerProtectionSchedulerStatus = .idle

    public var schedulerStatusPublisher: Published<DataBrokerProtectionSchedulerStatus>.Publisher {
        $schedulerStatus
    }

    // MARK: - Initializers

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

extension DataBrokerProtectionIPCClient: IPCServerInterface {

    public func register() {
        xpc.execute(call: { server in
            server.register()
        }, xpcReplyErrorHandler: { _ in
            // Intentional no-op as there's no completion block
            // If you add a completion block, please remember to call it here too!
        })
    }

    public func startScheduler(showWebView: Bool) {
        xpc.execute(call: { server in
            server.startScheduler(showWebView: showWebView)
        }, xpcReplyErrorHandler: { _ in
            // Intentional no-op as there's no completion block
            // If you add a completion block, please remember to call it here too!
        })
    }

    public func stopScheduler() {
        xpc.execute(call: { server in
            server.stopScheduler()
        }, xpcReplyErrorHandler: { _ in
            // Intentional no-op as there's no completion block
            // If you add a completion block, please remember to call it here too!
        })
    }

    public func optOutAllBrokers(showWebView: Bool, completion: @escaping ((Error?) -> Void)) {
        xpc.execute(call: { server in
            server.optOutAllBrokers(showWebView: showWebView, completion: completion)
        }, xpcReplyErrorHandler: { error in
            completion(error)
        })
    }

    public func scanAllBrokers(showWebView: Bool, completion: @escaping ((Error?) -> Void)) {
        xpc.execute(call: { server in
            server.scanAllBrokers(showWebView: showWebView, completion: completion)
        }, xpcReplyErrorHandler: { error in
            completion(error)
        })
    }

    public func runQueuedOperations(showWebView: Bool, completion: @escaping ((Error?) -> Void)) {
        xpc.execute(call: { server in
            server.runQueuedOperations(showWebView: showWebView, completion: completion)
        }, xpcReplyErrorHandler: { error in
            completion(error)
        })
    }

    public func runAllOperations(showWebView: Bool) {
        xpc.execute(call: { server in
            server.runAllOperations(showWebView: showWebView)
        }, xpcReplyErrorHandler: { _ in
            // Intentional no-op as there's no completion block
            // If you add a completion block, please remember to call it here too!
        })
    }
}

// MARK: - Incoming communication from the server

extension DataBrokerProtectionIPCClient: XPCClientInterface {
    func schedulerStatusChanged(_ payload: Data) {
        guard let status = try? JSONDecoder().decode(DataBrokerProtectionSchedulerStatus.self, from: payload) else {

            return
        }

        schedulerStatus = status
    }
}
