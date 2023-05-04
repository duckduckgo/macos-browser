//
//  NetworkProtectionDeviceManagerTests.swift
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
import XCTest
@testable import NetworkProtection

final class NetworkProtectionDeviceManagerTests: XCTestCase {
    var tokenStore: NetworkProtectionTokenStoreMock!
    var keyStore: NetworkProtectionKeyStoreMock!
    var temporaryURL: URL!
    var serverListStore: NetworkProtectionServerListFileSystemStore!

    override func setUp() {
        super.setUp()
        tokenStore = NetworkProtectionTokenStoreMock()
        tokenStore.token = "initialtoken"
        keyStore = NetworkProtectionKeyStoreMock()
        temporaryURL = temporaryFileURL()
        serverListStore = NetworkProtectionServerListFileSystemStore(fileURL: temporaryURL, errorEvents: nil)
    }

    override func tearDown() {
        tokenStore = nil
        keyStore = nil
        temporaryURL = nil
        serverListStore = nil
        super.tearDown()
    }

    func testDeviceManager() async {
        let server = NetworkProtectionServer.mockRegisteredServer
        let networkClient = NetworkProtectionMockClient(
            getServersReturnValue: .success([server]),
            registerServersReturnValue: .success([server]),
            redeemReturnValue: .success("IamANauthTOKEN")
        )

        let manager = NetworkProtectionDeviceManager(
            networkClient: networkClient,
            tokenStore: tokenStore,
            keyStore: keyStore,
            serverListStore: serverListStore,
            errorEvents: nil
        )

        let configuration: (TunnelConfiguration, NetworkProtectionServerInfo)

        do {
            configuration = try await manager.generateTunnelConfiguration(selectionMethod: .automatic)
        } catch {
            XCTFail("Unexpected error \(error.localizedDescription)")
            return
        }

        // Check that the device manager created a private key
        XCTAssertTrue((try? keyStore.storedPrivateKey()) != nil)

        // Check that the server list store was given a server list
        XCTAssertEqual((try? serverListStore.storedNetworkProtectionServerList()), [.mockRegisteredServer])

        XCTAssertEqual(configuration.0.interface.privateKey, try? keyStore.storedPrivateKey())
    }

    func testWhenGeneratingTunnelConfig_AndNoServersAreStored_ThenPrivateKeyIsCreated_AndRegisterEndpointIsCalled() async {
        let server = NetworkProtectionServer.mockBaseServer
        let registeredServer = NetworkProtectionServer.mockRegisteredServer
        let networkClient = NetworkProtectionMockClient(
            getServersReturnValue: .success([server]),
            registerServersReturnValue: .success([registeredServer]),
            redeemReturnValue: .success("IamANauthTOKEN")
        )

        let manager = NetworkProtectionDeviceManager(
            networkClient: networkClient,
            tokenStore: tokenStore,
            keyStore: keyStore,
            serverListStore: serverListStore,
            errorEvents: nil
        )

        XCTAssertNil(try? keyStore.storedPrivateKey())
        XCTAssertEqual(try? serverListStore.storedNetworkProtectionServerList(), [])
        XCTAssertFalse(networkClient.getServersCalled)
        XCTAssertFalse(networkClient.registerCalled)

        _ = try? await manager.generateTunnelConfiguration(selectionMethod: .automatic)

        XCTAssertNotNil(try? keyStore.storedPrivateKey())
        XCTAssertEqual(try? serverListStore.storedNetworkProtectionServerList(), [registeredServer])
        XCTAssertTrue(networkClient.getServersCalled)
        XCTAssertTrue(networkClient.registerCalled)
    }

    func testWhenGeneratingTunnelConfig_AndRegisteredServerIsFound_ThenRegisterEndpointIsNotCalled() async throws {
        let keyPair = keyStore.currentKeyPair()

        let server = NetworkProtectionServer.registeredServer(named: "Some Server", withPublicKey: keyPair.publicKey.base64Key)

        try serverListStore.store(serverList: [server])

        let networkClient = NetworkProtectionMockClient(
            getServersReturnValue: .success([server]),
            registerServersReturnValue: .success([server]),
            redeemReturnValue: .success("IamANauthTOKEN")
        )

        let manager = NetworkProtectionDeviceManager(
            networkClient: networkClient,
            tokenStore: tokenStore,
            keyStore: keyStore,
            serverListStore: serverListStore,
            errorEvents: nil
        )

        XCTAssertNotNil(try? keyStore.storedPrivateKey())
        XCTAssertEqual(try? serverListStore.storedNetworkProtectionServerList(), [server])
        XCTAssertFalse(networkClient.getServersCalled)
        XCTAssertFalse(networkClient.registerCalled)

        _ = try? await manager.generateTunnelConfiguration(selectionMethod: .automatic)

        XCTAssertNotNil(try? keyStore.storedPrivateKey())
        XCTAssertEqual(try? serverListStore.storedNetworkProtectionServerList(), [server])
        XCTAssertTrue(networkClient.getServersCalled)
        XCTAssertFalse(networkClient.registerCalled)
    }

    func testWhenGeneratingTunnelConfig_storedAuthTokenIsInvalidOnGettingServers_deletesToken() async {
        let server = NetworkProtectionServer.mockRegisteredServer
        let keyStore = NetworkProtectionKeyStoreMock()
        let temporaryURL = temporaryFileURL()
        let serverListStore = NetworkProtectionServerListFileSystemStore(fileURL: temporaryURL, errorEvents: nil)
        let networkClient = NetworkProtectionMockClient(
            getServersReturnValue: .failure(.invalidAuthToken),
            registerServersReturnValue: .success([server]),
            redeemReturnValue: .success("IamANauthTOKEN")
        )

        let manager = NetworkProtectionDeviceManager(
            networkClient: networkClient,
            tokenStore: tokenStore,
            keyStore: keyStore,
            serverListStore: serverListStore,
            errorEvents: nil
        )

        XCTAssertNotNil(tokenStore.token)

        _ = try? await manager.generateTunnelConfiguration(selectionMethod: .automatic)

        XCTAssertNil(tokenStore.token)
    }

    func testWhenGeneratingTunnelConfig_storedAuthTokenIsInvalidOnRegisteringServer_deletesToken() async {
        let server = NetworkProtectionServer.mockRegisteredServer
        let keyStore = NetworkProtectionKeyStoreMock()
        let temporaryURL = temporaryFileURL()
        let serverListStore = NetworkProtectionServerListFileSystemStore(fileURL: temporaryURL, errorEvents: nil)
        let networkClient = NetworkProtectionMockClient(
            getServersReturnValue: .success([server]),
            registerServersReturnValue: .failure(.invalidAuthToken),
            redeemReturnValue: .success("IamANauthTOKEN")
        )

        let manager = NetworkProtectionDeviceManager(
            networkClient: networkClient,
            tokenStore: tokenStore,
            keyStore: keyStore,
            serverListStore: serverListStore,
            errorEvents: nil
        )

        XCTAssertNotNil(tokenStore.token)

        _ = try? await manager.generateTunnelConfiguration(selectionMethod: .automatic)

        XCTAssertNil(tokenStore.token)
    }

    func testGettingClosestServerUsingTimeZone() async throws {
        let server = NetworkProtectionServer.mockRegisteredServer
        let serverListStore = NetworkProtectionServerListFileSystemStore(fileURL: temporaryURL, errorEvents: nil)
        let networkClient = NetworkProtectionMockClient(
            getServersReturnValue: .success([]),
            registerServersReturnValue: .success([server]),
            redeemReturnValue: .success("IamANauthTOKEN")
        )

        let manager = NetworkProtectionDeviceManager(
            networkClient: networkClient,
            tokenStore: tokenStore,
            keyStore: keyStore,
            serverListStore: serverListStore,
            errorEvents: nil
        )

        let servers = try JSONDecoder().decode([NetworkProtectionServer].self, from: TestData.mockServers)

        XCTAssertTrue(manager.closestServer(from: servers, timeZone: TimeZone(abbreviation: "PST")!)!.serverName.hasPrefix("egress.usw"))
        XCTAssertTrue(manager.closestServer(from: servers, timeZone: TimeZone(abbreviation: "PDT")!)!.serverName.hasPrefix("egress.usw"))
        XCTAssertTrue(manager.closestServer(from: servers, timeZone: TimeZone(abbreviation: "MST")!)!.serverName.hasPrefix("egress.usw"))
        XCTAssertTrue(manager.closestServer(from: servers, timeZone: TimeZone(abbreviation: "MDT")!)!.serverName.hasPrefix("egress.use"))
        XCTAssertTrue(manager.closestServer(from: servers, timeZone: TimeZone(abbreviation: "CST")!)!.serverName.hasPrefix("egress.use"))
        XCTAssertTrue(manager.closestServer(from: servers, timeZone: TimeZone(abbreviation: "CDT")!)!.serverName.hasPrefix("egress.use"))
        XCTAssertTrue(manager.closestServer(from: servers, timeZone: TimeZone(abbreviation: "EST")!)!.serverName.hasPrefix("egress.use"))
        XCTAssertTrue(manager.closestServer(from: servers, timeZone: TimeZone(abbreviation: "EDT")!)!.serverName.hasPrefix("egress.use"))
        XCTAssertTrue(manager.closestServer(from: servers, timeZone: TimeZone(abbreviation: "CET")!)!.serverName.hasPrefix("egress.euw"))
        XCTAssertTrue(manager.closestServer(from: servers, timeZone: TimeZone(abbreviation: "CEST")!)!.serverName.hasPrefix("egress.euw"))
    }

    func testWhenGettingClosestServer_AndMultipleServersAreAvailable_ThenARandomServerIsReturnedEachTime() throws {
        let server = NetworkProtectionServer.mockRegisteredServer
        let keyStore = NetworkProtectionKeyStoreMock()
        let temporaryURL = temporaryFileURL()
        let serverListStore = NetworkProtectionServerListFileSystemStore(fileURL: temporaryURL, errorEvents: nil)
        let networkClient = NetworkProtectionMockClient(
            getServersReturnValue: .success([]),
            registerServersReturnValue: .success([server]),
            redeemReturnValue: .success("IamANauthTOKEN")
        )

        let manager = NetworkProtectionDeviceManager(
            networkClient: networkClient,
            tokenStore: tokenStore,
            keyStore: keyStore,
            serverListStore: serverListStore,
            errorEvents: nil
        )

        let servers = try JSONDecoder().decode([NetworkProtectionServer].self, from: TestData.mockServers)

        var serverNames = Set<String>()

        // Iterate 100 times to try to have covered all possible choices
        for _ in 0...100 {
            let name = manager.closestServer(from: servers, timeZone: TimeZone(abbreviation: "PST")!)!.serverName
            serverNames.insert(name)
        }

        XCTAssertEqual(serverNames, ["egress.usw.1", "egress.usw.2"])
    }

    func testDecodingServers() throws {
        let servers1 = try JSONDecoder().decode([NetworkProtectionServer].self, from: TestData.mockServers)
        XCTAssertEqual(servers1.count, 6)

        let servers2 = try JSONDecoder().decode([NetworkProtectionServer].self, from: TestData.mockServers2)
        XCTAssertEqual(servers2.count, 6)
    }

}
