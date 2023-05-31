//
//  IPCConnection.swift
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

/// App --> Provider IPC
@objc protocol ProviderCommunication {
    func register(_ completionHandler: @escaping (Bool) -> Void)
}

/// Provider --> App IPC
@objc protocol AppCommunication {
    func reconnected()
    func reconnecting()
    func connectionFailure()
    func statusChanged(status: NEVPNStatus)
    func superceded()
}

/// The IPCConnection class is used by both the app and the system extension to communicate with each other
final class IPCConnection: NSObject {

    private var distributedNotificationCenter = DistributedNotificationCenter.forType(.networkProtection)

    // MARK: Properties

    var listener: NSXPCListener?
    var currentConnection: NSXPCConnection?
    let log: OSLog
    let memoryManagementLog: OSLog
    weak var delegate: AppCommunication?

    // MARK: - Initalizers

    init(log: OSLog, memoryManagementLog: OSLog) {
        os_log("[+] %{public}@", log: memoryManagementLog, type: .debug, Self.className())
        self.log = log
        self.memoryManagementLog = memoryManagementLog

        super.init()
    }

    deinit {
        os_log("[-] %{public}@", log: memoryManagementLog, type: .debug, Self.className())
    }

    // MARK: - Methods

    func startListener() {
        let machServiceName = NetworkProtectionExtensionMachService.serviceName()
        os_log("Starting IPC listener: %{public}@", log: log, type: .debug, machServiceName)

        let newListener = NSXPCListener(machServiceName: machServiceName)
        newListener.delegate = self
        newListener.resume()
        listener = newListener

        distributedNotificationCenter.post(.ipcListenerStarted)
        os_log("Listener started", log: log, type: .debug, Self.className())
    }

    /// This method is called by the app to register with the provider running in the system extension.
    func register(machServiceName: String, delegate: AppCommunication, completionHandler: @escaping (Bool) -> Void) {

        self.delegate = delegate

        guard currentConnection == nil else {
            os_log("Already registered with the provider", log: log, type: .debug)
            completionHandler(true)
            return
        }

        os_log("Mach service name: %{public}@", log: log, type: .info, machServiceName)
        let newConnection = NSXPCConnection(machServiceName: machServiceName, options: [])

        // The exported object is the delegate.
        newConnection.exportedInterface = NSXPCInterface(with: AppCommunication.self)
        newConnection.exportedObject = delegate

        // The remote object is the provider's IPCConnection instance.
        newConnection.remoteObjectInterface = NSXPCInterface(with: ProviderCommunication.self)

        newConnection.invalidationHandler = {
            self.currentConnection = nil
        }

        newConnection.interruptionHandler = {
            self.currentConnection = nil
        }

        currentConnection = newConnection
        newConnection.resume()

        guard let providerProxy = newConnection.remoteObjectProxyWithErrorHandler({ registerError in
            os_log("Failed to register with the provider: %{public}@", log: self.log, type: .error, registerError.localizedDescription)
            self.currentConnection?.invalidate()
            self.currentConnection = nil
            completionHandler(false)
        }) as? ProviderCommunication else {
            os_log("Failed to create a remote object proxy for the provider", log: log, type: .error)
            fatalError("Failed to create a remote object proxy for the provider")
        }

        providerProxy.register(completionHandler)
    }

    private func appProxy() -> AppCommunication? {
        guard let connection = currentConnection else {
            os_log("The app isn't registered for the IPCConnection", log: log, type: .error)
            return nil
        }

        guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ [weak self] promptError in
            guard let self else { return }
            os_log("IPCConnection error: %@", log: self.log, type: .error, promptError.localizedDescription)
            self.currentConnection = nil
        }) as? AppCommunication else {
            os_log("Failed to create a remote object proxy for the app", log: log, type: .error)
            fatalError("Failed to create a remote object proxy for the app")
        }

        return appProxy
    }

    func reconnected() {
        appProxy()?.reconnected()
    }

    func reconnecting() {
        os_log("IPC requesting proxy reconnecting notification", log: log, type: .info)
        appProxy()?.reconnecting()
    }

    func connectionFailure() {
        appProxy()?.connectionFailure()
    }

    func superceded() {
        appProxy()?.superceded()
    }

}

extension IPCConnection: NSXPCListenerDelegate {

    // MARK: NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        os_log("New connection", log: log, type: .debug)

        // The exported object is this IPCConnection instance.
        newConnection.exportedInterface = NSXPCInterface(with: ProviderCommunication.self)
        newConnection.exportedObject = IPCConnectionExportedObject(delegate: self)

        // The remote object is the delegate of the app's IPCConnection instance.
        newConnection.remoteObjectInterface = NSXPCInterface(with: AppCommunication.self)

        newConnection.invalidationHandler = { [weak self] in
            guard let self = self else { return }

            os_log("Connection invalidated", log: self.log, type: .debug)
            self.currentConnection = nil
        }

        newConnection.interruptionHandler = { [weak self] in
            guard let self = self else { return }

            os_log("Connection interrupted", log: self.log, type: .debug)
            self.currentConnection = nil
        }

        currentConnection = newConnection
        newConnection.resume()

        return true
    }

}

extension IPCConnection: ProviderCommunication {

    // MARK: ProviderCommunication

    func register(_ completionHandler: @escaping (Bool) -> Void) {
        os_log("App registered", log: log, type: .debug)
        completionHandler(true)
    }
}

final class IPCConnectionExportedObject: NSObject, ProviderCommunication {

    weak var delegate: ProviderCommunication?

    init(delegate: ProviderCommunication) {
        self.delegate = delegate
    }

    // MARK: ProviderCommunication

    func register(_ completionHandler: @escaping (Bool) -> Void) {
        delegate?.register(completionHandler) ?? completionHandler(false)
    }

}
