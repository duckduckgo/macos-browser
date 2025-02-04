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
import Common
import Foundation
import XPCHelper
import os.log

/// This protocol describes the server-side IPC interface for controlling the tunnel
///
public protocol IPCClientInterface: AnyObject {
}

public protocol DBPLoginItemStatusChecker {
    func doesHaveNecessaryPermissions() -> Bool
    func isInCorrectDirectory() -> Bool
}

/// This is the XPC interface with parameters that can be packed properly
@objc
protocol XPCClientInterface: NSObjectProtocol {
}

public final class DataBrokerProtectionIPCClient: NSObject {

    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let loginItemStatusChecker: DBPLoginItemStatusChecker

    // MARK: - XPC Communication

    let xpc: XPCClient<XPCClientInterface, XPCServerInterface>

    // MARK: - Initializers

    public init(machServiceName: String, pixelHandler: EventMapping<DataBrokerProtectionPixels>, loginItemStatusChecker: DBPLoginItemStatusChecker) {
        self.pixelHandler = pixelHandler
        self.loginItemStatusChecker = loginItemStatusChecker
        let clientInterface = NSXPCInterface(with: XPCClientInterface.self)
        let serverInterface = NSXPCInterface(with: XPCServerInterface.self)

        xpc = XPCClient(
            machServiceName: machServiceName,
            clientInterface: clientInterface,
            serverInterface: serverInterface)

        super.init()

        xpc.delegate = self
        xpc.onDisconnect = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                try await Task.sleep(interval: .seconds(1))
                // By calling register we make sure that XPC will connect as soon as it
                // becomes available again, as requests are queued.  This helps ensure
                // that the client app will always be connected to XPC.
                self.register()
            }
        }

        self.register()
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

    // MARK: - DataBrokerProtectionAgentAppEvents

    public func profileSaved(xpcMessageReceivedCompletion: @escaping (Error?) -> Void) {
        xpc.execute(call: { server in
            server.profileSaved(xpcMessageReceivedCompletion: xpcMessageReceivedCompletion)
        }, xpcReplyErrorHandler: xpcMessageReceivedCompletion)
    }

    public func appLaunched(xpcMessageReceivedCompletion: @escaping (Error?) -> Void) {
        xpc.execute(call: { server in
            server.appLaunched(xpcMessageReceivedCompletion: xpcMessageReceivedCompletion)
        }, xpcReplyErrorHandler: xpcMessageReceivedCompletion)
    }

    // MARK: - DataBrokerProtectionAgentDebugCommands

    public func openBrowser(domain: String) {
        xpc.execute(call: { server in
            server.openBrowser(domain: domain)
        }, xpcReplyErrorHandler: { error in
            Logger.dataBrokerProtection.error("Error \(error.localizedDescription)")
            // Intentional no-op as there's no completion block
            // If you add a completion block, please remember to call it here too!
        })
    }

    public func startImmediateOperations(showWebView: Bool) {
        xpc.execute(call: { server in
            server.startImmediateOperations(showWebView: showWebView)
        }, xpcReplyErrorHandler: { error in
            Logger.dataBrokerProtection.error("Error \(error.localizedDescription)")
            // Intentional no-op as there's no completion block
            // If you add a completion block, please remember to call it here too!
        })
    }

    public func startScheduledOperations(showWebView: Bool) {
        xpc.execute(call: { server in
            server.startScheduledOperations(showWebView: showWebView)
        }, xpcReplyErrorHandler: { error in
            Logger.dataBrokerProtection.error("Error \(error.localizedDescription)")
            // Intentional no-op as there's no completion block
            // If you add a completion block, please remember to call it here too!
        })
    }

    public func runAllOptOuts(showWebView: Bool) {
        xpc.execute(call: { server in
            server.runAllOptOuts(showWebView: showWebView)
        }, xpcReplyErrorHandler: { error in
            Logger.dataBrokerProtection.error("Error \(error.localizedDescription)")
            // Intentional no-op as there's no completion block
            // If you add a completion block, please remember to call it here too!
        })
    }

    public func getDebugMetadata() async -> DBPBackgroundAgentMetadata? {
        await withCheckedContinuation { continuation in
            xpc.execute(call: { server in
                server.getDebugMetadata { metaData in
                    continuation.resume(returning: metaData)
                }
            }, xpcReplyErrorHandler: { error in
                Logger.dataBrokerProtection.error("Error \(error.localizedDescription)")
                continuation.resume(returning: nil)
            })
        }
    }
}

// MARK: - Incoming communication from the server

extension DataBrokerProtectionIPCClient: XPCClientInterface {
}
