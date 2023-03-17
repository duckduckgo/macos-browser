//
//  NetworkProtectionDeviceManager.swift
//  DuckDuckGo
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
import os

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
    case failedToFetchServerList
    case failedToParseServerListResponse(Error)
    case failedToEncodeRegisterKeyRequest
    case failedToFetchRegisteredServers
    case failedToParseRegisteredServersResponse(Error)

    // Server list store errors
    case failedToEncodeServerList(Error)
    case failedToDecodeServerList(Error)
    case failedToWriteServerList(Error)
    case noServerListFound
    case couldNotCreateServerListDirectory(Error)
    case failedToReadServerList(Error)
    case serverListInconsistency

    // Keychain errors
    case failedToCastKeychainValueToData(field: String)
    case keychainReadError(field: String, status: Int32)
    case keychainWriteError(field: String, status: Int32)
    case keychainDeleteError(status: Int32)

    // Unhandled error
    case unhandledError(function: String, line: Int, error: Error)

    public var errorDescription: String? {
        // This is probably not the most elegant error to show to a user but
        // it's a great way to get detailed reports for those cases we haven't
        // provided good descriptions for yet.
        return "NetworkProtectionError.\(String(describing: self))"
    }

    /// When this is true, the error will assert.  If for any reason whe need a specific error to not assert,
    /// we can override that behaviour here.
    ///
    public var asserts: Bool {
        true
    }
}

public actor NetworkProtectionDeviceManager: NetworkProtectionDeviceManagement {
    private let networkClient: NetworkProtectionClient
    private let keyStore: NetworkProtectionKeyStore
    private let serverListStore: NetworkProtectionServerListStore

    private let errorEvents: EventMapping<NetworkProtectionError>?

    public init(networkClient: NetworkProtectionClient = NetworkProtectionBackendClient(),
                keyStore: NetworkProtectionKeyStore,
                serverListStore: NetworkProtectionServerListStore? = nil,
                errorEvents: EventMapping<NetworkProtectionError>?) {
        self.networkClient = networkClient
        self.keyStore = keyStore
        self.serverListStore = serverListStore ?? NetworkProtectionServerListFileSystemStore(errorEvents: errorEvents)
        self.errorEvents = errorEvents
    }

    /// Requests a new server list from the backend and updates it locally.
    /// This method will return the remote server list if available, or the local server list if there was a problem with the service call.
    ///
    private func serverList() async throws -> [NetworkProtectionServer] {
        let servers = await networkClient.getServers()
        let completeServerList: [NetworkProtectionServer]

        switch servers {
        case .success(let serverList):
            completeServerList = serverList
        case .failure(let failure):
            errorEvents?.fire(failure.networkProtectionError)
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

    /// Registers the device with the Network Protection backend.
    ///
    /// The flow for registration is as follows:
    /// 1. Look for an existing private key, and if one does not exist then generate it and store it in the Keychain
    /// 2. If the key is new, register it with all backend servers and return a tunnel configuration + its server info
    /// 3. If the key already existed, look up the stored set of backend servers and check if the preferred server is registered. If not, register it, and return the tunnel configuration + server info.
    public func generateTunnelConfiguration(selectionMethod: NetworkProtectionServerSelectionMethod) async throws -> (TunnelConfiguration, NetworkProtectionServerInfo) {

        let servers: [NetworkProtectionServer]

        do {
            servers = try await serverList()
        } catch let error as NetworkProtectionServerListStoreError {
            errorEvents?.fire(error.networkProtectionError)
            throw error
        } catch {
            errorEvents?.fire(.unhandledError(function: #function, line: #line, error: error))
            throw error
        }

        let closestServer: NetworkProtectionServer?

        switch selectionMethod {
        case .automatic:
            closestServer = self.closestServer(from: servers)
        case .preferredServer(let serverName):
            closestServer = server(in: servers, matching: serverName) ?? self.closestServer(from: servers)
        case .avoidServer(let serverToAvoid):
            closestServer = self.closestServer(from: servers.filter({ $0.serverName != serverToAvoid }))
        }

        guard var selectedServer = closestServer else {
            errorEvents?.fire(NetworkProtectionError.couldNotSelectClosestServer)
            throw NetworkProtectionError.couldNotSelectClosestServer
        }

        var keyPair = keyStore.currentKeyPair()

        if !selectedServer.isRegistered(with: keyPair.publicKey) {
            let registeredServersResult = await networkClient.register(publicKey: keyPair.publicKey, withServer: selectedServer.serverInfo)

            let registeredServers: [NetworkProtectionServer]

            switch registeredServersResult {
            case .success(let servers):
                registeredServers = servers

                guard let registeredServer = servers.first(where: { $0.serverName == selectedServer.serverName }) else {
                    // If we selected the server from the stored list, and after registering it and updating that list
                    // with the server reply we can't find it, something's quite wrong.
                    assertionFailure("There's an inconsistency with the list of servers returned by the endpoint")
                    // - TODO: does this require a privacy triage?
                    errorEvents?.fire(NetworkProtectionError.serverListInconsistency)
                    throw NetworkProtectionError.serverListInconsistency
                }

                selectedServer = registeredServer

                // We should not need this IF condition here, because we know registered servers will give us an expiration date,
                // but since the structure we're currently using makes the expiration date optional we need to have it.
                // - TODO: consider changing our server structure to not allow a missing expiration date here
                if let serverExpirationDate = selectedServer.expirationDate {
                    if keyPair.expirationDate > serverExpirationDate {
                        keyPair = keyStore.updateCurrentKeyPair(newExpirationDate: serverExpirationDate)
                    }
                }
            case .failure(let error):
                errorEvents?.fire(error.networkProtectionError)
                throw error
            }

            // Persist the server list:

            do {
                try serverListStore.updateServerListCache(with: registeredServers)
            } catch let error as NetworkProtectionServerListStoreError {
                errorEvents?.fire(error.networkProtectionError)
                // Intentionally not rethrowing, as this failure is not critical for this method
            } catch {
                errorEvents?.fire(.unhandledError(function: #function, line: #line, error: error))
                // Intentionally not rethrowing, as this failure is not critical for this method
            }
        }

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

    /// The app currently has no way to tell which server is most appropriate for the user.
    /// For now, use the time zone to determine which one is more likely to be closest.
    /// This will be addressed by a backend project later.
    nonisolated func closestServer(from servers: [NetworkProtectionServer], timeZone: TimeZone = .current) -> NetworkProtectionServer? {
        let deviceDifferenceFromGMT = timeZone.secondsFromGMT()
        var currentBestDistanceToServer = Int.max
        var closestServers: [NetworkProtectionServer] = []

        for server in servers {
            let serverDifferenceFromGMT = server.serverInfo.attributes.timezoneOffset
            let distanceToServer = abs(deviceDifferenceFromGMT - serverDifferenceFromGMT)

            if distanceToServer < currentBestDistanceToServer {
                currentBestDistanceToServer = distanceToServer
                closestServers = [server]
            } else if distanceToServer == currentBestDistanceToServer {
                closestServers.append(server)
            }
        }

        return closestServers.randomElement()
    }

    func tunnelConfiguration(interfacePrivateKey: PrivateKey,
                             server: NetworkProtectionServer) throws -> TunnelConfiguration {

        guard let allowedIPs = server.allowedIPs else {
            throw NetworkProtectionError.noServerRegistrationInfo
        }

        guard let serverPublicKey = PublicKey(base64Key: server.serverInfo.publicKey) else {
            throw NetworkProtectionError.couldNotGetPeerPublicKey
        }

        guard let serverAddress = server.serverInfo.serverAddresses.first, let serverEndpoint = Endpoint(from: serverAddress) else {
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
        interface.dns = [DNSServer(from: "1.1.1.1")!]
        interface.addresses = [addressRange]

        return interface
    }
}
