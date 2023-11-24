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
import Common

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

    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>

    // MARK: - XPC Communication

    let xpc: XPCClient<XPCClientInterface, XPCServerInterface>

    // MARK: - Scheduler Status

    @Published
    private(set) public var schedulerStatus: DataBrokerProtectionSchedulerStatus = .idle

    public var schedulerStatusPublisher: Published<DataBrokerProtectionSchedulerStatus>.Publisher {
        $schedulerStatus
    }

    // MARK: - Initializers

    public init(machServiceName: String, pixelHandler: EventMapping<DataBrokerProtectionPixels>) {
        self.pixelHandler = pixelHandler
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
        self.pixelHandler.fire(.ipcServerRegister)
        xpc.execute(call: { server in
            server.register()
        }, xpcReplyErrorHandler: { _ in
            // Intentional no-op as there's no completion block
            // If you add a completion block, please remember to call it here too!
        })
    }

    public func startScheduler(showWebView: Bool) {
        self.pixelHandler.fire(.ipcServerStartScheduler)
        xpc.execute(call: { server in
            server.startScheduler(showWebView: showWebView)
        }, xpcReplyErrorHandler: { _ in
            // Intentional no-op as there's no completion block
            // If you add a completion block, please remember to call it here too!
        })
    }

    public func stopScheduler() {
        self.pixelHandler.fire(.ipcServerStopScheduler)
        xpc.execute(call: { server in
            server.stopScheduler()
        }, xpcReplyErrorHandler: { _ in
            // Intentional no-op as there's no completion block
            // If you add a completion block, please remember to call it here too!
        })
    }

    public func optOutAllBrokers(showWebView: Bool, completion: @escaping ((Error?) -> Void)) {
        self.pixelHandler.fire(.ipcServerOptOutAllBrokers)
        xpc.execute(call: { server in
            server.optOutAllBrokers(showWebView: showWebView) { error in
                self.pixelHandler.fire(.ipcServerRunQueuedOperationsCompletion(error: error?.toEquatableError()))
                completion(error)
            }
        }, xpcReplyErrorHandler: { error in
            self.pixelHandler.fire(.ipcServerRunQueuedOperationsCompletion(error: error.toEquatableError()))
            completion(error)
        })
    }

    public func scanAllBrokers(showWebView: Bool, completion: @escaping ((Error?) -> Void)) {
        self.pixelHandler.fire(.ipcServerScanAllBrokers)
        xpc.execute(call: { server in
            server.scanAllBrokers(showWebView: showWebView) { error in
                self.pixelHandler.fire(.ipcServerScanAllBrokersCompletion(error: error?.toEquatableError()))
                completion(error)
            }
        }, xpcReplyErrorHandler: { error in
            self.pixelHandler.fire(.ipcServerScanAllBrokersCompletion(error: error.toEquatableError()))
            completion(error)
        })
    }

    public func runQueuedOperations(showWebView: Bool, completion: @escaping ((Error?) -> Void)) {
        self.pixelHandler.fire(.ipcServerRunQueuedOperations)
        xpc.execute(call: { server in
            server.runQueuedOperations(showWebView: showWebView) { error in
                self.pixelHandler.fire(.ipcServerRunQueuedOperationsCompletion(error: error?.toEquatableError()))
                completion(error)
            }
        }, xpcReplyErrorHandler: { error in
            self.pixelHandler.fire(.ipcServerRunQueuedOperationsCompletion(error: error.toEquatableError()))
            completion(error)
        })
    }

    public func runAllOperations(showWebView: Bool) {
        self.pixelHandler.fire(.ipcServerRunAllOperations)
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
