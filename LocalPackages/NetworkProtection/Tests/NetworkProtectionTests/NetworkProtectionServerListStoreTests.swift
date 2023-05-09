//
//  NetworkProtectionServerListStoreTests.swift
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
import XCTest
@testable import NetworkProtection

final class NetworkProtectionServerListStoreTests: XCTestCase {

    func testWhenStoringList_ThenListCanBeSuccessfullyFetched() {
        let temporaryURL = temporaryFileURL()
        let store = NetworkProtectionServerListFileSystemStore(fileURL: temporaryURL, errorEvents: nil)

        let storedServers = [NetworkProtectionServer.mockBaseServer]
        XCTAssertNoThrow(try store.store(serverList: storedServers))

        let fetchedServers = (try? store.storedNetworkProtectionServerList()) ?? []
        XCTAssertEqual(fetchedServers, storedServers)
    }

    func testWhenRemovingServerList_ThenServerListCanNoLongerBeFetched() {
        let temporaryURL = temporaryFileURL()
        let store = NetworkProtectionServerListFileSystemStore(fileURL: temporaryURL, errorEvents: nil)

        let storedServers = [NetworkProtectionServer.mockBaseServer]
        XCTAssertNoThrow(try store.store(serverList: storedServers))

        let fetchedServers = (try? store.storedNetworkProtectionServerList()) ?? []
        XCTAssertEqual(fetchedServers, storedServers)

        XCTAssertNoThrow(try store.removeServerList())

        let newFetchedServers = (try? store.storedNetworkProtectionServerList()) ?? []
        XCTAssertTrue(newFetchedServers.isEmpty)
    }

    func testWhenStoringNewServerList_AndExistingListHasRegisteredServers_ThenRegistrationStatusPersists_AndVacantServersAreRemoved() throws {
        let temporaryURL = temporaryFileURL()
        let store = NetworkProtectionServerListFileSystemStore(fileURL: temporaryURL, errorEvents: nil)

        let existingList: [NetworkProtectionServer] = [.registeredServer(named: "A"), .baseServer(named: "B")]
        try store.store(serverList: existingList)

        let registeredList: [NetworkProtectionServer] = [.baseServer(named: "A")]
        try store.store(serverList: registeredList)

        let storedList = try store.storedNetworkProtectionServerList()
        XCTAssertEqual(storedList, [.registeredServer(named: "A")])
    }

    func testWhenUpdatingRegisteredServer_AndServerExistsInList_ThenServerIsUpdated() throws {
        let temporaryURL = temporaryFileURL()
        let store = NetworkProtectionServerListFileSystemStore(fileURL: temporaryURL, errorEvents: nil)

        let existingList: [NetworkProtectionServer] = [.registeredServer(named: "C"), .baseServer(named: "B"), .baseServer(named: "A")]
        try store.store(serverList: existingList)

        let registeredList: [NetworkProtectionServer] = [.registeredServer(named: "B")]
        try store.updateServerListCache(with: registeredList)

        let storedList = try store.storedNetworkProtectionServerList()
        XCTAssertEqual(storedList, [.baseServer(named: "A"), .registeredServer(named: "B"), .registeredServer(named: "C")])
    }

    func testWhenUpdatingRegisteredServers_AndServerDoesNotExistInList_ThenServerIsAddedToList() throws {
        let temporaryURL = temporaryFileURL()
        let store = NetworkProtectionServerListFileSystemStore(fileURL: temporaryURL, errorEvents: nil)

        let firstList: [NetworkProtectionServer] = [.baseServer(named: "A")]
        try store.store(serverList: firstList)
        let firstStoredList = try store.storedNetworkProtectionServerList()
        XCTAssertEqual(firstStoredList, [.baseServer(named: "A")])

        let secondList: [NetworkProtectionServer] = [.baseServer(named: "B")]
        try store.store(serverList: secondList)
        let secondStoredList = try store.storedNetworkProtectionServerList()
        XCTAssertEqual(secondStoredList, [.baseServer(named: "B")])

        let thirdList: [NetworkProtectionServer] = [.baseServer(named: "A"), .baseServer(named: "B")]
        try store.store(serverList: thirdList)
        let thirdStoredList = try store.storedNetworkProtectionServerList()
        XCTAssertEqual(thirdStoredList, [.baseServer(named: "A"), .baseServer(named: "B")])
    }

}
