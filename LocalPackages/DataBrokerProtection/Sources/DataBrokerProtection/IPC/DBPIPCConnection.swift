//
//  DBPIPCConnection.swift
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
import Network
import NetworkExtension
import Common

/// App --> Agent IPC
@objc public protocol MainAppToDBPBackgroundAgentCommunication {
    func register(_ completionHandler: @escaping (Bool) -> Void)

    func appDidStart()
    func profileModified()
    func startScanPressed() // TODO need to make sure we're explicit about starting the agent in the UI

    // Legacy function kept for debugging purposes. They should be deleted where possible
    func startScheduler(showWebView: Bool)
    func stopScheduler()
    func optOutAllBrokers(showWebView: Bool, completion: (() -> Void)?) // TODO can delete?
    func scanAllBrokers(showWebView: Bool, completion: (() -> Void)?)
    func runQueuedOperations(showWebView: Bool, completion: (() -> Void)?)
    func runAllOperations(showWebView: Bool)
}

/// Agent --> App IPC
@objc public protocol DBPBackgroundAgentToMainAppCommunication {
    func brokersScanCompleted()
}

/// The DBPIPCConnection class is used by both the app and the background agent to communicate with each other
final public class DBPIPCConnection: NSObject {

    // MARK: Properties

    var listener: NSXPCListener?
    var currentConnection: NSXPCConnection?
    var currentAgentProxy: MainAppToDBPBackgroundAgentCommunication? // TODO should we store this? Idk
    let log: OSLog
    let memoryManagementLog: OSLog
    weak var delegate: DBPBackgroundAgentToMainAppCommunication?

    // MARK: - Initalizers

    public init(log: OSLog, memoryManagementLog: OSLog) {
        os_log("[+] %{public}@", log: memoryManagementLog, type: .debug, Self.className())
        self.log = log
        self.memoryManagementLog = memoryManagementLog

        super.init()
    }

    deinit {
        os_log("[-] %{public}@", log: memoryManagementLog, type: .debug, Self.className())
    }

    // MARK: - Listening and Registration

    public func startListener(machServiceName: String) {

        os_log("Starting IPC listener: %{public}@", log: log, type: .debug, machServiceName)

        let newListener = NSXPCListener(machServiceName: machServiceName)
        newListener.delegate = self
        newListener.resume()
        listener = newListener

        os_log("Listener started", log: log, type: .debug, Self.className())
    }

    /// This method is called by the app to register with the provider running in the agent.
    public func register(machServiceName: String, delegate: DBPBackgroundAgentToMainAppCommunication, completionHandler: @escaping (Bool) -> Void) {

        self.delegate = delegate

        guard currentConnection == nil else {
            os_log("Already registered with the provider", log: log, type: .debug)
            completionHandler(true)
            return
        }

        os_log("Mach service name: %{public}@", log: log, type: .info, machServiceName)
        let newConnection = NSXPCConnection(machServiceName: machServiceName, options: [])

        // The exported object is the delegate.
        newConnection.exportedInterface = NSXPCInterface(with: DBPBackgroundAgentToMainAppCommunication.self)
        newConnection.exportedObject = delegate

        // The remote object is the provider's DBPIPCConnection instance.
        newConnection.remoteObjectInterface = NSXPCInterface(with: MainAppToDBPBackgroundAgentCommunication.self)

        newConnection.invalidationHandler = {
            self.currentConnection = nil
        }

        newConnection.interruptionHandler = {
            self.currentConnection = nil
        }

        currentConnection = newConnection
        newConnection.resume()

        guard let agentProxy = newConnection.remoteObjectProxyWithErrorHandler({ registerError in
            os_log("Failed to register with the agent: %{public}@", log: self.log, type: .error, registerError.localizedDescription)
            self.currentConnection?.invalidate()
            self.currentConnection = nil
            completionHandler(false)
        }) as? MainAppToDBPBackgroundAgentCommunication else {
            os_log("Failed to create a remote object proxy for the agent", log: log, type: .error)
            fatalError("Failed to create a remote object proxy for the agent")
        }

        currentAgentProxy = agentProxy
        agentProxy.register(completionHandler)
    }

    // MARK: Agent to App

    public func brokersScanCompleted() {
        guard let connection = currentConnection else {
            os_log("The app isn't registered for the IPCConnection", log: log, type: .error)
            return
        }

        guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
            os_log("IPCConnection error: %@", log: self.log, type: .error, promptError.localizedDescription)
            self.currentConnection = nil
        }) as? DBPBackgroundAgentToMainAppCommunication else {
            os_log("Failed to create a remote object proxy for the app", log: log, type: .error)
            fatalError("Failed to create a remote object proxy for the app")
        }

        appProxy.brokersScanCompleted()
    }

    // MARK: App to Agent

    public func appDidStart() {
        currentAgentProxy?.appDidStart()
    }

    public func profileModified() {
        currentAgentProxy?.profileModified()
    }

    public func startScanPressed() {
        currentAgentProxy?.startScanPressed()
    }

    // Legacy function kept for debugging purposes. They should be deleted where possible
    public func startScheduler(showWebView: Bool) {
        currentAgentProxy?.startScheduler(showWebView: showWebView)
    }

    public func stopScheduler() {
        currentAgentProxy?.stopScheduler()
    }

    public func optOutAllBrokers(showWebView: Bool, completion: (() -> Void)?) { // TODO can delete?
        currentAgentProxy?.optOutAllBrokers(showWebView: showWebView, completion: completion)
    }

    public func scanAllBrokers(showWebView: Bool, completion: (() -> Void)?) {
        currentAgentProxy?.scanAllBrokers(showWebView: showWebView, completion: completion)
    }

    public func runQueuedOperations(showWebView: Bool, completion: (() -> Void)?) {
        currentAgentProxy?.runQueuedOperations(showWebView: showWebView, completion: completion)
    }

    public func runAllOperations(showWebView: Bool) {
        currentAgentProxy?.runAllOperations(showWebView: showWebView)
    }
}

extension DBPIPCConnection: NSXPCListenerDelegate {

    // MARK: NSXPCListenerDelegate

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        os_log("New connection", log: log, type: .debug)

        // The exported object is this IPCConnection instance.
        newConnection.exportedInterface = NSXPCInterface(with: MainAppToDBPBackgroundAgentCommunication.self)
        newConnection.exportedObject = self

        // The remote object is the delegate of the app's IPCConnection instance.
        newConnection.remoteObjectInterface = NSXPCInterface(with: DBPBackgroundAgentToMainAppCommunication.self)

        newConnection.invalidationHandler = { [weak self] in
            guard let self = self else {
                return
            }

            os_log("Connection invalidated", log: self.log, type: .debug)
            self.currentConnection = nil
        }

        newConnection.interruptionHandler = { [weak self] in
            guard let self = self else {
                return
            }

            os_log("Connection interrupted", log: self.log, type: .debug)
            self.currentConnection = nil
        }

        currentConnection = newConnection
        newConnection.resume()

        return true
    }
}
