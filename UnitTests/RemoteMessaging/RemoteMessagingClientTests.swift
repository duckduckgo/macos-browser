//
//  RemoteMessagingClientTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import Bookmarks
import Foundation
import Persistence
import RemoteMessaging
import Freemium
import XCTest
@testable import DuckDuckGo_Privacy_Browser

struct MockRemoteMessagingStoreProvider: RemoteMessagingStoreProviding {
    func makeRemoteMessagingStore(database: CoreDataDatabase, availabilityProvider: RemoteMessagingAvailabilityProviding) -> RemoteMessagingStoring {
        MockRemoteMessagingStore()
    }
}

final class MockRemoteMessagingConfigFetcher: RemoteMessagingConfigFetching {
    func fetchRemoteMessagingConfig() async throws -> RemoteMessageResponse.JsonRemoteMessagingConfig {
        let json = #"{ "version": 1, "messages": [], "rules": [] }"#
        let jsonData = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        return try decoder.decode(RemoteMessageResponse.JsonRemoteMessagingConfig.self, from: jsonData)
    }
}

final class MockFreemiumDBPUserStateManager: FreemiumDBPUserStateManager {
    var didCallResetAllState = false

    var didActivate = false
    var didPostFirstProfileSavedNotification = false
    var didPostResultsNotification = false
    var didDismissHomePagePromotion = false
    var firstProfileSavedTimestamp: Date?
    var upgradeToSubscriptionTimestamp: Date?
    var firstScanResults: FreemiumDBPMatchResults?

    func resetAllState() {
        didCallResetAllState = true
    }
}

final class RemoteMessagingClientTests: XCTestCase {

    var client: RemoteMessagingClient!

    var storeProvider: MockRemoteMessagingStoreProvider!
    var availabilityProvider: MockRemoteMessagingAvailabilityProvider!

    var remoteMessagingDatabase: CoreDataDatabase!
    var remoteMessagingDatabaseLocation: URL!
    var bookmarksDatabase: CoreDataDatabase!
    var bookmarksDatabaseLocation: URL!

    override func setUpWithError() throws {
        setUpRemoteMessagingDatabase()
        setUpBookmarksDatabase()

        availabilityProvider = MockRemoteMessagingAvailabilityProvider()
        storeProvider = MockRemoteMessagingStoreProvider()
    }

    override func tearDownWithError() throws {
        try tearDownBookmarksDatabase()
        try tearDownRemoteMessagingDatabase()
        try super.tearDownWithError()
    }

    private func setUpRemoteMessagingDatabase() {
        remoteMessagingDatabaseLocation = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bundle = RemoteMessaging.bundle
        guard let model = CoreDataDatabase.loadModel(from: bundle, named: "RemoteMessaging") else {
            XCTFail("Failed to load model")
            return
        }
        remoteMessagingDatabase = CoreDataDatabase(name: type(of: self).description(), containerLocation: remoteMessagingDatabaseLocation, model: model)
        remoteMessagingDatabase.loadStore()
    }

    private func setUpBookmarksDatabase() {
        bookmarksDatabaseLocation = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bundle = Bookmarks.bundle
        guard let model = CoreDataDatabase.loadModel(from: bundle, named: "BookmarksModel") else {
            XCTFail("Failed to load model")
            return
        }
        bookmarksDatabase = CoreDataDatabase(name: type(of: self).description(), containerLocation: bookmarksDatabaseLocation, model: model)
        bookmarksDatabase.loadStore()
    }

    private func tearDownRemoteMessagingDatabase() throws {
        try remoteMessagingDatabase.tearDown(deleteStores: true)
        remoteMessagingDatabase = nil
        try FileManager.default.removeItem(at: remoteMessagingDatabaseLocation)
    }

    private func tearDownBookmarksDatabase() throws {
        try bookmarksDatabase.tearDown(deleteStores: true)
        bookmarksDatabase = nil
        try FileManager.default.removeItem(at: bookmarksDatabaseLocation)
    }

    private func makeClient() {
        client = RemoteMessagingClient(
            database: remoteMessagingDatabase,
            configFetcher: MockRemoteMessagingConfigFetcher(),
            configMatcherProvider: RemoteMessagingConfigMatcherProvider(
                bookmarksDatabase: bookmarksDatabase,
                appearancePreferences: AppearancePreferences(persistor: AppearancePreferencesPersistorMock()),
                pinnedTabsManager: PinnedTabsManager(),
                internalUserDecider: InternalUserDeciderMock(),
                statisticsStore: MockStatisticsStore(),
                variantManager: MockVariantManager()
            ),
            remoteMessagingAvailabilityProvider: availabilityProvider
        )
    }

    // MARK: -

    func testWhenFeatureFlagIsDisabledThenStoreIsNotCreated() {
        availabilityProvider.isRemoteMessagingAvailable = false
        makeClient()
        XCTAssertNil(client.store)
    }

    func testWhenFeatureFlagIsEnabledThenStoreIsInitialized() {
        availabilityProvider.isRemoteMessagingAvailable = true
        makeClient()
        XCTAssertNotNil(client.store)
    }

    func testWhenFeatureFlagBecomesEnabledThenStoreIsCreated() {
        availabilityProvider.isRemoteMessagingAvailable = false
        makeClient()
        XCTAssertNil(client.store)

        availabilityProvider.isRemoteMessagingAvailable = true
        XCTAssertNotNil(client.store)
    }
}
