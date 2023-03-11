/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file contains the implementation of the app <-> provider IPC connection
*/

import Foundation
import os.log
import Network

/// App --> Provider IPC
@objc protocol ProviderCommunication {
    func register(_ completionHandler: @escaping (Bool) -> Void)
}

/// Provider --> App IPC
@objc protocol AppCommunication {
    func reconnected()
    func reconnecting()
    func connectionFailure()
}

enum FlowInfoKey: String {
    case localPort
    case remoteAddress
}

/// The IPCConnection class is used by both the app and the system extension to communicate with each other
final class IPCConnection: NSObject {

    private var distributedNotificationCenter = DistributedNotificationCenter.forType(.networkProtection)

    // MARK: Properties

    var listener: NSXPCListener?
    var currentConnection: NSXPCConnection?
    weak var delegate: AppCommunication?
    static let shared = IPCConnection()

    // MARK: Methods

    func startListener() {
        let machServiceName = NetworkProtectionExtensionMachService.serviceName()

        let newListener = NSXPCListener(machServiceName: machServiceName)
        newListener.delegate = self
        newListener.resume()
        listener = newListener

        distributedNotificationCenter.postNotificationName(.NetPIPCListenerStarted, object: nil, userInfo: nil, options: [.deliverImmediately, .postToAllSessions])
    }

    /// This method is called by the app to register with the provider running in the system extension.
    func register(machServiceName: String, delegate: AppCommunication, completionHandler: @escaping (Bool) -> Void) {

        self.delegate = delegate

        guard currentConnection == nil else {
            os_log("🔵 Already registered with the provider")
            completionHandler(true)
            return
        }

        os_log("🔵 Mach service name: %{public}@", machServiceName)
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
            os_log("🔵 Failed to register with the provider: %{public}@", registerError.localizedDescription)
            self.currentConnection?.invalidate()
            self.currentConnection = nil
            completionHandler(false)
        }) as? ProviderCommunication else {
            fatalError("🔵 Failed to create a remote object proxy for the provider")
        }

        providerProxy.register(completionHandler)
    }

    func test() {
        guard let connection = currentConnection else {
            os_log("🔵 The app isn't registered for the IPCConnection")
            return
        }

        guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
            os_log("🔵 IPCConnection error: %@", promptError.localizedDescription)
            self.currentConnection = nil
        }) as? AppCommunication else {
            fatalError("🔵 Failed to create a remote object proxy for the app")
        }

        appProxy.reconnected()
    }

    func reconnected() {
        guard let connection = currentConnection else {
            os_log("🔵 The app isn't registered for the IPCConnection")
            return
        }

        guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
            os_log("🔵 IPCConnection error: %@", promptError.localizedDescription)
            self.currentConnection = nil
        }) as? AppCommunication else {
            os_log("🔵 Failed to create a remote object proxy for the app")
            fatalError("🔵 Failed to create a remote object proxy for the app")
        }

        appProxy.reconnected()
    }

    func reconnecting() {
        guard let connection = currentConnection else {
            os_log("🔵 The app isn't registered for the IPCConnection")
            return
        }

        guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
            os_log("🔵 IPCConnection error: %@", promptError.localizedDescription)
            self.currentConnection = nil
        }) as? AppCommunication else {
            os_log("🔵 Failed to create a remote object proxy for the app")
            fatalError("🔵 Failed to create a remote object proxy for the app")
        }

        os_log("🔵 IPC requesting proxy reconnecting notification")
        appProxy.reconnecting()
    }

    func connectionFailure() {
        guard let connection = currentConnection else {
            os_log("🔵 The app isn't registered for the IPCConnection")
            return
        }

        guard let appProxy = connection.remoteObjectProxyWithErrorHandler({ promptError in
            os_log("🔵 IPCConnection error: %{public}@", promptError.localizedDescription)
            self.currentConnection = nil
        }) as? AppCommunication else {
            os_log("🔵 Failed to create a remote object proxy for the app")
            fatalError("🔵 Failed to create a remote object proxy for the app")
        }

        appProxy.connectionFailure()
    }
}

extension IPCConnection: NSXPCListenerDelegate {

    // MARK: NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        os_log("🔵 New connection")

        // The exported object is this IPCConnection instance.
        newConnection.exportedInterface = NSXPCInterface(with: ProviderCommunication.self)
        newConnection.exportedObject = self

        // The remote object is the delegate of the app's IPCConnection instance.
        newConnection.remoteObjectInterface = NSXPCInterface(with: AppCommunication.self)

        newConnection.invalidationHandler = {
            os_log("🔵 Sysex detects invalidated")
            self.currentConnection = nil
        }

        newConnection.interruptionHandler = {
            os_log("🔵 Sysex detects interrupted")
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
        os_log("🔵 Sysex detects app registered 👍")
        completionHandler(true)
    }
}
