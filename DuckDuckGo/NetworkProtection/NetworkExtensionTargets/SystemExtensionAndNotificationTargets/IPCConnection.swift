/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file contains the implementation of the app <-> provider IPC connection
*/

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
        os_log("Starting IPC listener", log: log, type: .debug, Self.className())

        let machServiceName = NetworkProtectionExtensionMachService.serviceName()

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

    func test() {
        guard let connection = currentConnection else {
            os_log("The app isn't registered for the IPCConnection", log: log, type: .error)
            return
        }

        guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
            os_log("IPCConnection error: %@", log: self.log, type: .error, promptError.localizedDescription)
            self.currentConnection = nil
        }) as? AppCommunication else {
            os_log("Failed to create a remote object proxy for the app", log: log, type: .error)
            fatalError("Failed to create a remote object proxy for the app")
        }

        appProxy.reconnected()
    }

    func reconnected() {
        guard let connection = currentConnection else {
            os_log("The app isn't registered for the IPCConnection", log: log, type: .error)
            return
        }

        guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
            os_log("IPCConnection error: %@", log: self.log, type: .error, promptError.localizedDescription)
            self.currentConnection = nil
        }) as? AppCommunication else {
            os_log("Failed to create a remote object proxy for the app", log: log, type: .error)
            fatalError("Failed to create a remote object proxy for the app")
        }

        appProxy.reconnected()
    }

    func reconnecting() {
        guard let connection = currentConnection else {
            os_log("The app isn't registered for the IPCConnection", log: log, type: .error)
            return
        }

        guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
            os_log("IPCConnection error: %@", log: self.log, type: .error, promptError.localizedDescription)
            self.currentConnection = nil
        }) as? AppCommunication else {
            os_log("Failed to create a remote object proxy for the app", log: log, type: .error)
            fatalError("Failed to create a remote object proxy for the app")
        }

        os_log("IPC requesting proxy reconnecting notification", log: log, type: .info)
        appProxy.reconnecting()
    }

    func connectionFailure() {
        guard let connection = currentConnection else {
            os_log("The app isn't registered for the IPCConnection", log: log, type: .error)
            return
        }

        guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
            os_log("IPCConnection error: %{public}@", log: self.log, type: .error, promptError.localizedDescription)
            self.currentConnection = nil
        }) as? AppCommunication else {
            os_log("Failed to create a remote object proxy for the app", log: log, type: .error)
            fatalError("Failed to create a remote object proxy for the app")
        }

        appProxy.connectionFailure()
    }
}

extension IPCConnection: NSXPCListenerDelegate {

    // MARK: NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        os_log("New connection", log: log, type: .debug)

        // The exported object is this IPCConnection instance.
        newConnection.exportedInterface = NSXPCInterface(with: ProviderCommunication.self)
        newConnection.exportedObject = self

        // The remote object is the delegate of the app's IPCConnection instance.
        newConnection.remoteObjectInterface = NSXPCInterface(with: AppCommunication.self)

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

extension IPCConnection: ProviderCommunication {

    // MARK: ProviderCommunication

    func register(_ completionHandler: @escaping (Bool) -> Void) {
        os_log("App registered", log: log, type: .debug)
        completionHandler(true)
    }
}
