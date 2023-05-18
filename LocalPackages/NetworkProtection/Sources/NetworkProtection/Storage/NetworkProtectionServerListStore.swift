//
//  NetworkProtectionServer.swift
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

import Common
import Foundation

public protocol NetworkProtectionServerListStore {

    /// Replace the existing stored Network Protection server list, if one exists. If any servers exist on disk but not in this array, then the ones on disk will be removed.
    func store(serverList: [NetworkProtectionServer]) throws

    /// Update the existing server cache with a list of registered servers. This will update existing servers if they are found, or will add them into the list otherwise.
    func updateServerListCache(with registeredServers: [NetworkProtectionServer]) throws

    /// Returns the list of stored Network Protection servers.
    ///
    /// - Note: This list is sorted by server name alphabetically.
    func storedNetworkProtectionServerList() throws -> [NetworkProtectionServer]

    func removeServerList() throws

}

public enum NetworkProtectionServerListStoreError: Error, NetworkProtectionErrorConvertible {
    case failedToEncodeServerList(Error)
    case failedToDecodeServerList(Error)
    case failedToWriteServerList(Error)
    case couldNotCreateServerListDirectory(Error)
    case failedToReadServerList(Error)

    var networkProtectionError: NetworkProtectionError {
        switch self {
        case .failedToEncodeServerList(let error): return .failedToEncodeServerList(error)
        case .failedToDecodeServerList(let error): return .failedToDecodeServerList(error)
        case .failedToWriteServerList(let error): return .failedToWriteServerList(error)
        case .couldNotCreateServerListDirectory(let error): return .couldNotCreateServerListDirectory(error)
        case .failedToReadServerList(let error): return .failedToReadServerList(error)
        }
    }
}

/// Stores the most recent Network Protection server list.
///
/// This list is used to present a list of servers to the user. Because this list is cached, it may not represent the true list of servers and should be periodically refreshed.
/// This list also remembers which servers have been registered with, and can be used to check whether registration is needed before connecting.
public class NetworkProtectionServerListFileSystemStore: NetworkProtectionServerListStore {

    enum Constants {
        static let defaultFileDir = "com.duckduckgo.network-protection"
        static let defaultFileName = "network_protection_servers.json"
    }

    private let fileURL: URL
    private let errorEvents: EventMapping<NetworkProtectionError>?

    public convenience init(errorEvents: EventMapping<NetworkProtectionError>?) {
        let fileURL: URL

        do {
#if NETP_SYSTEM_EXTENSION
            fileURL = try FileManager.default.url(for: .applicationSupportDirectory, in: .localDomainMask, appropriateFor: nil, create: true)
#else
            fileURL = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
#endif
        } catch {
            fatalError() // This likely shouldn't be a hard failure
        }

        self.init(fileURL: fileURL.appending(Constants.defaultFileDir).appendingPathComponent(Constants.defaultFileName, isDirectory: false),
                  errorEvents: errorEvents)
    }

    init(fileURL: URL, errorEvents: EventMapping<NetworkProtectionError>?) {
        self.fileURL = fileURL
        self.errorEvents = errorEvents
    }

    public func store(serverList: [NetworkProtectionServer]) throws {
        // 1. Get the existing server list

        let existingServerList: [NetworkProtectionServer]

        do {
            existingServerList = try storedNetworkProtectionServerList()
        } catch let error as NetworkProtectionServerListStoreError {
            errorEvents?.fire(error.networkProtectionError)
            // Intentionally not rethrowing, as this may mean our stored server list structure is stale
            // This method can continue executing and provide a working user experience

            existingServerList = []
        }

        // 2. Iterate over existing servers, and for those registered then update the new servers' registration info

        var serverListMap = Dictionary(uniqueKeysWithValues: serverList.map({ ($0.serverName, $0) }))

        for existingServer in existingServerList where existingServer.isRegistered {
            guard let incomingServer = serverListMap[existingServer.serverName] else {
                continue
            }

            serverListMap[existingServer.serverName] = NetworkProtectionServer(
                registeredPublicKey: existingServer.registeredPublicKey,
                allowedIPs: existingServer.allowedIPs,
                serverInfo: incomingServer.serverInfo,
                expirationDate: incomingServer.expirationDate
            )
        }

        // 3. Sort alphabetically and store to disk

        let sortedServerList = serverListMap.values.sorted { first, second in
            first.serverInfo.name < second.serverInfo.name
        }

        try replaceServerList(with: sortedServerList)
    }

    public func updateServerListCache(with registeredServers: [NetworkProtectionServer]) throws {
        let existingServerList: [NetworkProtectionServer]

        do {
            existingServerList = try storedNetworkProtectionServerList()
        } catch {
            throw error
        }

        var serverListMap = Dictionary(uniqueKeysWithValues: existingServerList.map({ ($0.serverName, $0) }))

        for registeredServer in registeredServers {
            serverListMap[registeredServer.serverName] = registeredServer
        }

        let sortedServers = serverListMap.values.sorted { first, second in
            first.serverInfo.name < second.serverInfo.name
        }

        try replaceServerList(with: sortedServers)
    }

    public func storedNetworkProtectionServerList() throws -> [NetworkProtectionServer] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data: Data

        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            try removeServerList()
            throw NetworkProtectionServerListStoreError.failedToReadServerList(error)
        }

        do {
            return try JSONDecoder().decode([NetworkProtectionServer].self, from: data)
        } catch {
            try removeServerList()
            throw NetworkProtectionServerListStoreError.failedToDecodeServerList(error)
        }
    }

    public func removeServerList() throws {
        if FileManager.default.fileExists(atPath: fileURL.relativePath) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private func replaceServerList(with newList: [NetworkProtectionServer]) throws {
        try removeServerList()

        let serializedJSONData: Data

        do {
            serializedJSONData = try JSONEncoder().encode(newList)
        } catch {
            throw NetworkProtectionServerListStoreError.failedToEncodeServerList(error)
        }

        let directory = fileURL.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw NetworkProtectionServerListStoreError.couldNotCreateServerListDirectory(error)
        }

        do {
            try serializedJSONData.write(to: fileURL, options: [.atomic])
        } catch {
            throw NetworkProtectionServerListStoreError.failedToWriteServerList(error)
        }
    }

}
