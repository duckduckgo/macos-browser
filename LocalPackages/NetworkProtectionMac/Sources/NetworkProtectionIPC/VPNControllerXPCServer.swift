//
//  VPNControllerXPCServer.swift
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
import NetworkProtection
import XPCHelper

/// This protocol describes the server-side IPC interface for controlling the tunnel
///
public protocol XPCServerInterface: AnyObject {
    var version: String { get }
    var bundlePath: String { get }

    /// Registers a connection with the server.
    ///
    /// This is the point where the server will start sending status updates to the client.
    ///
    func register(completion: @escaping (Error?) -> Void)

    func register(version: String, bundlePath: String, completion: @escaping (Error?) -> Void)

    /// Start the VPN tunnel.
    ///
    /// - Parameters:
    ///     - completion: the completion closure.  This will be called as soon as the IPC request has been processed, and won't
    ///         signal successful completion of the request.
    ///
    func start(completion: @escaping (Error?) -> Void)

    /// Stop the VPN tunnel.
    ///
    /// - Parameters:
    ///     - completion: the completion closure.  This will be called as soon as the IPC request has been processed, and won't
    ///         signal successful completion of the request.
    ///
    func stop(completion: @escaping (Error?) -> Void)

    /// Fetches the last error directly from the tunnel manager.
    ///
    func fetchLastError(completion: @escaping (Error?) -> Void)

    /// Commands
    ///
    func command(_ command: VPNCommand) async throws
}

public extension XPCServerInterface {
    var version: String { DefaultIPCMetadataCollector.version }
    var bundlePath: String { DefaultIPCMetadataCollector.bundlePath }
}

/// This protocol describes the server-side XPC interface.
///
/// The object that implements this interface takes care of unpacking any encoded data and forwarding
/// calls to the IPC interface when appropriate.
///
@objc
protocol XPCServerInterfaceObjC {
    /// Registers a connection with the server.
    ///
    /// This is the point where the server will start sending status updates to the client.
    ///
    func register(completion: @escaping (Error?) -> Void)

    func register(version: String, bundlePath: String, completion: @escaping (Error?) -> Void)

    /// Start the VPN tunnel.
    ///
    func start(completion: @escaping (Error?) -> Void)

    /// Stop the VPN tunnel.
    ///
    func stop(completion: @escaping (Error?) -> Void)

    /// Fetches the last error directly from the tunnel manager.
    ///
    func fetchLastError(completion: @escaping (Error?) -> Void)

    /// Commands
    ///
    func command(_ payload: Data, completion: @escaping (Error?) -> Void)
}

public final class VPNControllerXPCServer {
    let xpc: XPCServer<XPCClientInterfaceObjC, XPCServerInterfaceObjC>

    enum IPCError: Error {
        case cannotDecodeDebugCommand
    }

    /// The delegate.
    ///
    public weak var serverDelegate: XPCServerInterface?

    public init(machServiceName: String) {
        let clientInterface = NSXPCInterface(with: XPCClientInterfaceObjC.self)
        let serverInterface = NSXPCInterface(with: XPCServerInterfaceObjC.self)

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

extension VPNControllerXPCServer: XPCClientInterface {

    public func errorChanged(_ error: String?) {
        xpc.forEachClient { client in
            client.errorChanged(error: error)
        }
    }

    public func serverInfoChanged(_ serverInfo: NetworkProtectionStatusServerInfo) {
        let payload: Data

        do {
            payload = try JSONEncoder().encode(serverInfo)
        } catch {
            return
        }

        xpc.forEachClient { client in
            client.serverInfoChanged(payload: payload)
        }
    }

    /// Sends a statusChanged IPC message to all connections, through the proxy objects.
    ///
    public func statusChanged(_ status: ConnectionStatus) {
        let payload: Data

        do {
            payload = try JSONEncoder().encode(status)
        } catch {
            return
        }

        xpc.forEachClient { client in
            client.statusChanged(payload: payload)
        }
    }

    public func dataVolumeUpdated(_ dataVolume: DataVolume) {
        let payload: Data

        do {
            payload = try JSONEncoder().encode(dataVolume)
        } catch {
            return
        }

        xpc.forEachClient { client in
            client.dataVolumeUpdated(payload: payload)
        }
    }

    public func knownFailureUpdated(_ failure: KnownFailure?) {
        let payload: Data

        do {
            payload = try JSONEncoder().encode(failure)
        } catch {
            return
        }

        xpc.forEachClient { client in
            client.knownFailureUpdated(payload: payload)
        }
    }
}

// MARK: - Incoming communication from a client

extension VPNControllerXPCServer: XPCServerInterfaceObjC {

    func register(completion: @escaping (Error?) -> Void) {
        serverDelegate?.register(completion: completion)
    }

    func register(version: String, bundlePath: String, completion: @escaping (Error?) -> Void) {
        serverDelegate?.register(version: version, bundlePath: bundlePath, completion: completion)
    }

    func start(completion: @escaping (Error?) -> Void) {
        serverDelegate?.start(completion: completion)
    }

    func stop(completion: @escaping (Error?) -> Void) {
        serverDelegate?.stop(completion: completion)
    }

    func fetchLastError(completion: @escaping (Error?) -> Void) {
        serverDelegate?.fetchLastError(completion: completion)
    }

    func command(_ payload: Data, completion: @escaping (Error?) -> Void) {
        guard let command = try? JSONDecoder().decode(VPNCommand.self, from: payload) else {
            completion(IPCError.cannotDecodeDebugCommand)
            return
        }

        Task {
            do {
                try await serverDelegate?.command(command)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
}
