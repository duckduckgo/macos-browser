//
//  NetworkProtectionDeviceManager.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import Common

public enum NetworkProtectionServerSelectionMethod {
    case automatic
    case preferredServer(serverName: String)
    case avoidServer(serverName: String)
}

public protocol NetworkProtectionDeviceManagement {

    func generateTunnelConfiguration(selectionMethod: NetworkProtectionServerSelectionMethod) async throws -> (TunnelConfiguration, NetworkProtectionServerInfo)

}

protocol NetworkProtectionErrorConvertible {
    var networkProtectionError: NetworkProtectionError { get }
}

public enum NetworkProtectionError: LocalizedError {
    // Tunnel configuration errors
    case noServerRegistrationInfo
    case couldNotSelectClosestServer
    case couldNotGetPeerPublicKey
    case couldNotGetPeerHostName
    case couldNotGetInterfaceAddressRange

    // Client errors
    case failedToFetchServerList(Error?)
    case failedToParseServerListResponse(Error)
    case failedToEncodeRegisterKeyRequest
    case failedToFetchRegisteredServers(Error?)
    case failedToParseRegisteredServersResponse(Error)
    case failedToEncodeRedeemRequest
    case invalidInviteCode
    case failedToRedeemInviteCode(Error?)
    case failedToParseRedeemResponse(Error)
    case invalidAuthToken
    case serverListInconsistency

    // Server list store errors
    case failedToEncodeServerList(Error)
    case failedToDecodeServerList(Error)
    case failedToWriteServerList(Error)
    case noServerListFound
    case couldNotCreateServerListDirectory(Error)
    case failedToReadServerList(Error)

    // Keychain errors
    case failedToCastKeychainValueToData(field: String)
    case keychainReadError(field: String, status: Int32)
    case keychainWriteError(field: String, status: Int32)
    case keychainDeleteError(status: Int32)

    // Auth errors
    case noAuthTokenFound

    // Unhandled error
    case unhandledError(function: String, line: Int, error: Error)

    public var errorDescription: String? {
        // This is probably not the most elegant error to show to a user but
        // it's a great way to get detailed reports for those cases we haven't
        // provided good descriptions for yet.
        return "NetworkProtectionError.\(String(describing: self))"
    }
}

public actor NetworkProtectionDeviceManager: NetworkProtectionDeviceManagement {
    private let networkClient: NetworkProtectionClient
    private let tokenStore: NetworkProtectionTokenStore
    private let keyStore: NetworkProtectionKeyStore
    private let serverListStore: NetworkProtectionServerListStore

    private let errorEvents: EventMapping<NetworkProtectionError>?

    public init(networkClient: NetworkProtectionClient = NetworkProtectionBackendClient(),
                tokenStore: NetworkProtectionTokenStore,
                keyStore: NetworkProtectionKeyStore,
                serverListStore: NetworkProtectionServerListStore? = nil,
                errorEvents: EventMapping<NetworkProtectionError>?) {
        self.networkClient = networkClient
        self.tokenStore = tokenStore
        self.keyStore = keyStore
        self.serverListStore = serverListStore ?? NetworkProtectionServerListFileSystemStore(errorEvents: errorEvents)
        self.errorEvents = errorEvents
    }

    /// Requests a new server list from the backend and updates it locally.
    /// This method will return the remote server list if available, or the local server list if there was a problem with the service call.
    ///
    public func refreshServerList() async throws -> [NetworkProtectionServer] {
        guard let token = tokenStore.fetchToken() else {
            throw NetworkProtectionError.noAuthTokenFound
        }
        let servers = await networkClient.getServers(authToken: token)
        let completeServerList: [NetworkProtectionServer]

        switch servers {
        case .success(let serverList):
            completeServerList = serverList
        case .failure(let failure):
            handle(clientError: failure)
            return try serverListStore.storedNetworkProtectionServerList()
        }

        do {
            try serverListStore.store(serverList: completeServerList)
        } catch let error as NetworkProtectionServerListStoreError {
            errorEvents?.fire(error.networkProtectionError)
            // Intentionally not rethrowing as the failing call is not critical to provide
            // a working UX.
        } catch {
            errorEvents?.fire(.unhandledError(function: #function, line: #line, error: error))
            // Intentionally not rethrowing as the failing call is not critical to provide
            // a working UX.
        }

        return completeServerList
    }

    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity
    /// Registers the device with the Network Protection backend.
    ///
    /// The flow for registration is as follows:
    /// 1. Look for an existing private key, and if one does not exist then generate it and store it in the Keychain
    /// 2. If the key is new, register it with all backend servers and return a tunnel configuration + its server info
    /// 3. If the key already existed, look up the stored set of backend servers and check if the preferred server is registered. If not, register it, and return the tunnel configuration + server info.
    ///
    public func generateTunnelConfiguration(selectionMethod: NetworkProtectionServerSelectionMethod) async throws -> (TunnelConfiguration, NetworkProtectionServerInfo) {

        let (selectedServer, keyPair) = try await register(selectionMethod: selectionMethod)

        do {
            let configuration = try tunnelConfiguration(interfacePrivateKey: keyPair.privateKey, server: selectedServer)
            return (configuration, selectedServer.serverInfo)
        } catch let error as NetworkProtectionError {
            errorEvents?.fire(error)
            throw error
        } catch {
            errorEvents?.fire(.unhandledError(function: #function, line: #line, error: error))
            throw error
        }
    }

    /// Registers the client with a server following the specified server selection method.  Returns the precise server that was selected and the keyPair to use
    /// for the tunnel configuration.
    ///
    /// - Parameters:
    ///     - selectionMethod: the server selection method
    ///     - keyPair: the key pair that was used to register with the server, and that should be used to configure the tunnel
    ///
    /// - Throws:`NetworkProtectionError`
    ///
    private func register(selectionMethod: NetworkProtectionServerSelectionMethod) async throws -> (server: NetworkProtectionServer, keyPair: KeyPair) {

        guard let token = tokenStore.fetchToken() else {
            throw NetworkProtectionError.noAuthTokenFound
        }

        let selectedServerName: String?
        let excludedServerName: String?

        switch selectionMethod {
        case .automatic:
            selectedServerName = nil
            excludedServerName = nil
        case .preferredServer(let serverName):
            selectedServerName = serverName
            excludedServerName = nil
        case .avoidServer(let serverToAvoid):
            selectedServerName = nil
            excludedServerName = serverToAvoid
        }

        var keyPair = keyStore.currentKeyPair()
        let registeredServersResult = await networkClient.register(authToken: token, publicKey: keyPair.publicKey, withServerNamed: selectedServerName)
        let selectedServer: NetworkProtectionServer

        switch registeredServersResult {
        case .success(let registeredServers):
            do {
                try serverListStore.store(serverList: registeredServers)
            } catch let error as NetworkProtectionServerListStoreError {
                errorEvents?.fire(error.networkProtectionError)
                // Intentionally not rethrowing, as this failure is not critical for this method
            } catch {
                errorEvents?.fire(.unhandledError(function: #function, line: #line, error: error))
                // Intentionally not rethrowing, as this failure is not critical for this method
            }

            guard let registeredServer = registeredServers.first(where: { $0.serverName != excludedServerName }) else {
                // If we're looking to exclude a server we should have a few other options available.  If we can't find any
                // then it means theres an inconsistency in the server list that was returned.
                errorEvents?.fire(NetworkProtectionError.serverListInconsistency)

                let cachedServer = try cachedServer(registeredWith: keyPair)
                return (cachedServer, keyPair)
            }

            selectedServer = registeredServer

            // We should not need this IF condition here, because we know registered servers will give us an expiration date,
            // but since the structure we're currently using makes the expiration date optional we need to have it.
            // We should consider changing our server structure to not allow a missing expiration date here.
            if let serverExpirationDate = selectedServer.expirationDate {
                if keyPair.expirationDate > serverExpirationDate {
                    keyPair = keyStore.updateCurrentKeyPair(newExpirationDate: serverExpirationDate)
                }
            }

            return (selectedServer, keyPair)
        case .failure(let error):
            handle(clientError: error)

            let cachedServer = try cachedServer(registeredWith: keyPair)
            return (cachedServer, keyPair)
        }
    }

    /// Retrieves the first cached server that's registered with the specified key pair.
    ///
    private func cachedServer(registeredWith keyPair: KeyPair) throws -> NetworkProtectionServer {
        os_log("Returning first cached server", log: .networkProtectionPixel)

        do {
            guard let server = try serverListStore.storedNetworkProtectionServerList().first(where: { $0.isRegistered(with: keyPair.publicKey) }) else {
                errorEvents?.fire(NetworkProtectionError.noServerListFound)
                throw NetworkProtectionError.noServerListFound
            }

            return server
        } catch let error as NetworkProtectionError {
            errorEvents?.fire(error)
            throw error
        } catch {
            errorEvents?.fire(NetworkProtectionError.unhandledError(function: #function, line: #line, error: error))
            throw NetworkProtectionError.unhandledError(function: #function, line: #line, error: error)
        }
    }

    // MARK: - Internal

    func server(in servers: [NetworkProtectionServer], matching name: String?) -> NetworkProtectionServer? {
        guard let name = name else {
            return nil
        }

        let matchingServer = servers.first { server in
            return server.serverName == name
        }

        return matchingServer
    }

    func tunnelConfiguration(interfacePrivateKey: PrivateKey,
                             server: NetworkProtectionServer) throws -> TunnelConfiguration {

        guard let allowedIPs = server.allowedIPs else {
            throw NetworkProtectionError.noServerRegistrationInfo
        }

        guard let serverPublicKey = PublicKey(base64Key: server.serverInfo.publicKey) else {
            throw NetworkProtectionError.couldNotGetPeerPublicKey
        }

        guard let serverEndpoint = server.serverInfo.endpoint else {
            throw NetworkProtectionError.couldNotGetPeerHostName
        }

        let peerConfiguration = peerConfiguration(serverPublicKey: serverPublicKey, serverEndpoint: serverEndpoint)

        guard let closestIP = allowedIPs.first, let interfaceAddressRange = IPAddressRange(from: closestIP) else {
            throw NetworkProtectionError.couldNotGetInterfaceAddressRange
        }

        let interface = interfaceConfiguration(privateKey: interfacePrivateKey, addressRange: interfaceAddressRange)

        return TunnelConfiguration(name: "Network Protection", interface: interface, peers: [peerConfiguration])
    }

    func peerConfiguration(serverPublicKey: PublicKey, serverEndpoint: Endpoint) -> PeerConfiguration {
        var peerConfiguration = PeerConfiguration(publicKey: serverPublicKey)

        peerConfiguration.allowedIPs = [IPAddressRange(from: "0.0.0.0/0")!, IPAddressRange(from: "::/0")!]
        peerConfiguration.endpoint = serverEndpoint

        return peerConfiguration
    }

    func interfaceConfiguration(privateKey: PrivateKey, addressRange: IPAddressRange) -> InterfaceConfiguration {
        var interface = InterfaceConfiguration(privateKey: privateKey)

        interface.listenPort = 51821
        interface.dns = [DNSServer(from: "10.11.12.1")!]
        interface.addresses = [addressRange]

        return interface
    }

    private func handle(clientError: NetworkProtectionClientError) {
        if case .invalidAuthToken = clientError {
            tokenStore.deleteToken()
        }
        errorEvents?.fire(clientError.networkProtectionError)
    }
}
