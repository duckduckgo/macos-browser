//
//  DataBrokerProtectionIPCServer.swift
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

@objc(DBPBackgroundAgentMetadata)
public final class DBPBackgroundAgentMetadata: NSObject, NSSecureCoding {
    enum Consts {
        static let backgroundAgentVersionKey = "backgroundAgentVersion"
        static let isAgentRunningKey = "isAgentRunning"
        static let agentSchedulerStateKey = "agentSchedulerState"
        static let lastSchedulerSessionStartTimestampKey = "lastSchedulerSessionStartTimestamp"
    }

    public static var supportsSecureCoding: Bool = true

    let backgroundAgentVersion: String
    let isAgentRunning: Bool
    let agentSchedulerState: String
    let lastSchedulerSessionStartTimestamp: Double?

    public init(backgroundAgentVersion: String,
                isAgentRunning: Bool,
                agentSchedulerState: String,
                lastSchedulerSessionStartTimestamp: Double?) {
        self.backgroundAgentVersion = backgroundAgentVersion
        self.isAgentRunning = isAgentRunning
        self.agentSchedulerState = agentSchedulerState
        self.lastSchedulerSessionStartTimestamp = lastSchedulerSessionStartTimestamp
    }

    public init?(coder: NSCoder) {
        guard let backgroundAgentVersion = coder.decodeObject(of: NSString.self,
                                                              forKey: Consts.backgroundAgentVersionKey) as? String,
              let agentSchedulerState = coder.decodeObject(of: NSString.self,
                                                           forKey: Consts.agentSchedulerStateKey) as? String else {
            return nil
        }

        self.backgroundAgentVersion = backgroundAgentVersion
        self.isAgentRunning = coder.decodeBool(forKey: Consts.isAgentRunningKey)
        self.agentSchedulerState = agentSchedulerState
        self.lastSchedulerSessionStartTimestamp = coder.decodeObject(
            of: NSNumber.self,
            forKey: Consts.lastSchedulerSessionStartTimestampKey
        )?.doubleValue
    }

    public func encode(with coder: NSCoder) {
        coder.encode(self.backgroundAgentVersion as NSString, forKey: Consts.backgroundAgentVersionKey)
        coder.encode(self.isAgentRunning, forKey: Consts.isAgentRunningKey)
        coder.encode(self.agentSchedulerState as NSString, forKey: Consts.agentSchedulerStateKey)

        if let lastSchedulerSessionStartTimestamp = self.lastSchedulerSessionStartTimestamp {
            coder.encode(lastSchedulerSessionStartTimestamp as NSNumber, forKey: Consts.lastSchedulerSessionStartTimestampKey)
        }
    }
}

/// This protocol describes the server-side IPC interface for controlling the tunnel
///
public protocol IPCServerInterface: AnyObject, DataBrokerProtectionAgentDebugCommands {
    /// Registers a connection with the server.
    ///
    /// This is the point where the server will start sending status updates to the client.
    ///
    func register()

    // MARK: - DataBrokerProtectionAgentAppEvents

    func profileSaved(xpcMessageReceivedCompletion: @escaping (Error?) -> Void)
    func appLaunched(xpcMessageReceivedCompletion: @escaping (Error?) -> Void)
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

    // MARK: - DataBrokerProtectionAgentAppEvents

    func profileSaved(xpcMessageReceivedCompletion: @escaping (Error?) -> Void)
    func appLaunched(xpcMessageReceivedCompletion: @escaping (Error?) -> Void)

    // MARK: - DataBrokerProtectionAgentDebugCommands

    /// Opens a browser window with the specified domain
    ///
    func openBrowser(domain: String)

    func startImmediateOperations(showWebView: Bool)
    func startScheduledOperations(showWebView: Bool)
    func runAllOptOuts(showWebView: Bool)
    func getDebugMetadata(completion: @escaping (DBPBackgroundAgentMetadata?) -> Void)
}

protocol DataBrokerProtectionIPCServer: IPCClientInterface, XPCServerInterface {
    var serverDelegate: DataBrokerProtectionAppToAgentInterface? { get set }

    init(machServiceName: String)

    func activate()
}

public final class DefaultDataBrokerProtectionIPCServer: DataBrokerProtectionIPCServer {
    let xpc: XPCServer<XPCClientInterface, XPCServerInterface>

    public weak var serverDelegate: DataBrokerProtectionAppToAgentInterface?

    public init(machServiceName: String) {
        let clientInterface = NSXPCInterface(with: XPCClientInterface.self)
        let serverInterface = NSXPCInterface(with: XPCServerInterface.self)

        xpc = XPCServer(
            machServiceName: machServiceName,
            clientInterface: clientInterface,
            serverInterface: serverInterface)

        xpc.delegate = self
    }

    // DataBrokerProtectionIPCServer

    public func activate() {
        xpc.activate()
    }
}

// MARK: - Outgoing communication to the clients

extension DefaultDataBrokerProtectionIPCServer: IPCClientInterface {
}

// MARK: - Incoming communication from a client

extension DefaultDataBrokerProtectionIPCServer: XPCServerInterface {

    func register() {

    }

    // MARK: - DataBrokerProtectionAgentAppEvents

    func profileSaved(xpcMessageReceivedCompletion: @escaping (Error?) -> Void) {
        xpcMessageReceivedCompletion(nil)
        serverDelegate?.profileSaved()
    }

    func appLaunched(xpcMessageReceivedCompletion: @escaping (Error?) -> Void) {
        xpcMessageReceivedCompletion(nil)
        serverDelegate?.appLaunched()
    }

    // MARK: - DataBrokerProtectionAgentDebugCommands

    func openBrowser(domain: String) {
        serverDelegate?.openBrowser(domain: domain)
    }

    func startImmediateOperations(showWebView: Bool) {
        serverDelegate?.startImmediateOperations(showWebView: showWebView)
    }

    func startScheduledOperations(showWebView: Bool) {
        serverDelegate?.startScheduledOperations(showWebView: showWebView)
    }

    func runAllOptOuts(showWebView: Bool) {
        serverDelegate?.runAllOptOuts(showWebView: showWebView)
    }

    func getDebugMetadata(completion: @escaping (DBPBackgroundAgentMetadata?) -> Void) {
        Task {
            let metaData = await serverDelegate?.getDebugMetadata()
            completion(metaData)
        }
    }
}
