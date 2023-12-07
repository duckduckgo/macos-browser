//
//  SyncPreferencesTests.swift
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

import Bookmarks
import Combine
import Persistence
import SyncUI
import XCTest
@testable import BrowserServicesKit
@testable import DDGSync
@testable import DuckDuckGo_Privacy_Browser

final class SyncPreferencesTests: XCTestCase {

    let scheduler = CapturingScheduler()
    let managementDialogModel = ManagementDialogModel()
    var ddgSyncing: MockDDGSyncing!
    var syncBookmarksAdapter: SyncBookmarksAdapter!
    var appearancePersistor = MockPersistor()
    var appearancePreferences: AppearancePreferences!
    var syncPreferences: SyncPreferences!
    var testRecoveryCode = "some code"

    var bookmarksDatabase: CoreDataDatabase!
    var location: URL!

    override func setUp() {
        setUpDatabase()
        appearancePreferences = AppearancePreferences(persistor: appearancePersistor)
        ddgSyncing = MockDDGSyncing(authState: .inactive, scheduler: scheduler, isSyncInProgress: false)

        syncBookmarksAdapter = SyncBookmarksAdapter(database: bookmarksDatabase, appearancePreferences: appearancePreferences)

        syncPreferences = SyncPreferences(
            syncService: ddgSyncing,
            syncBookmarksAdapter: syncBookmarksAdapter,
            appearancePreferences: appearancePreferences,
            managementDialogModel: managementDialogModel
        )
    }

    override func tearDown() {
        ddgSyncing = nil
        syncPreferences = nil
        tearDownDatabase()
    }

    private func setUpDatabase() {
        location = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        let bundle = Bookmarks.bundle
        guard let model = CoreDataDatabase.loadModel(from: bundle, named: "BookmarksModel") else {
            XCTFail("Failed to load model")
            return
        }
        bookmarksDatabase = CoreDataDatabase(name: className, containerLocation: location, model: model)
        bookmarksDatabase.loadStore()
    }

    private func tearDownDatabase() {
        try? bookmarksDatabase.tearDown(deleteStores: true)
        bookmarksDatabase = nil
        try? FileManager.default.removeItem(at: location)
    }

    func testOnInitDelegateIsSet() {
        XCTAssertNotNil(managementDialogModel.delegate)
    }

    func testSyncIsEnabledReturnsCorrectValue() {
        XCTAssertFalse(syncPreferences.isSyncEnabled)

        ddgSyncing.account = SyncAccount(deviceId: "some device", deviceName: "", deviceType: "", userId: "", primaryKey: Data(), secretKey: Data(), token: nil, state: .active)

        XCTAssertTrue(syncPreferences.isSyncEnabled)
    }

    func testCorrectRecoveryCodeIsReturned() {
        let account = SyncAccount(deviceId: "some device", deviceName: "", deviceType: "", userId: "", primaryKey: Data(), secretKey: Data(), token: nil, state: .active)
        ddgSyncing.account = account

        XCTAssertEqual(syncPreferences.recoveryCode, account.recoveryCode)
    }

    @MainActor func testOnPresentRecoverSyncAccountDialogThenRecoverAccountDialogShown() {
        syncPreferences.recoverDataPressed()

        XCTAssertEqual(managementDialogModel.currentDialog, .recoverSyncedData)
    }

    @MainActor func testOnSyncWithServerPressedThenSyncWithServerDialogShown() {
        syncPreferences.syncWithServerPressed()

        XCTAssertEqual(managementDialogModel.currentDialog, .syncWithServer)
    }

    @MainActor func testOnPresentTurnOffSyncConfirmDialogThenTurnOffSyncShown() {
        syncPreferences.turnOffSyncPressed()

        XCTAssertEqual(managementDialogModel.currentDialog, .turnOffSync)
    }

    @MainActor func testOnPresentRemoveDeviceThenRemoveDEviceShown() {
        let device = SyncDevice(kind: .desktop, name: "test", id: "test")
        syncPreferences.presentRemoveDevice(device)

        XCTAssertEqual(managementDialogModel.currentDialog, .removeDevice(device))
    }

    @MainActor func testOnTurnOffSyncThenSyncServiceIsDisconnected() async {
        let expectation = XCTestExpectation(description: "Disconnect completed")
        Task {
            syncPreferences.turnOffSync()
            XCTAssertNil(managementDialogModel.currentDialog)
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertTrue(ddgSyncing.disconnectCalled)
    }

}

class MockDDGSyncing: DDGSyncing {
    let registeredDevices = [RegisteredDevice(id: "1", name: "Device 1", type: "desktop"), RegisteredDevice(id: "2", name: "Device 2", type: "mobile"), RegisteredDevice(id: "3", name: "Device 1", type: "desktop")]
    var disconnectCalled = false

    var dataProvidersSource: DataProvidersSource?

    @Published var authState: SyncAuthState = .inactive

    var authStatePublisher: AnyPublisher<SyncAuthState, Never> {
        $authState.eraseToAnyPublisher()
    }

    var account: SyncAccount?

    var scheduler: Scheduling

    @Published var isSyncInProgress: Bool

    var isSyncInProgressPublisher: AnyPublisher<Bool, Never> {
        $isSyncInProgress.eraseToAnyPublisher()
    }

    init(dataProvidersSource: DataProvidersSource? = nil, authState: SyncAuthState, account: SyncAccount? = nil, scheduler: Scheduling, isSyncInProgress: Bool) {
        self.dataProvidersSource = dataProvidersSource
        self.authState = authState
        self.account = account
        self.scheduler = scheduler
        self.isSyncInProgress = isSyncInProgress
    }

    func initializeIfNeeded() {
    }

    func createAccount(deviceName: String, deviceType: String) async throws {
    }

    func login(_ recoveryKey: SyncCode.RecoveryKey, deviceName: String, deviceType: String) async throws -> [RegisteredDevice] {
        return []
    }

    func remoteConnect() throws -> RemoteConnecting {
        return MockRemoteConnecting()
    }

    func transmitRecoveryKey(_ connectCode: SyncCode.ConnectCode) async throws {
    }

    func disconnect() async throws {
        disconnectCalled = true
    }

    func disconnect(deviceId: String) async throws {
    }

    func fetchDevices() async throws -> [RegisteredDevice] {
        return registeredDevices
    }

    func updateDeviceName(_ name: String) async throws -> [RegisteredDevice] {
        return []
    }

    func deleteAccount() async throws {
    }

    var serverEnvironment: ServerEnvironment = .production

    func updateServerEnvironment(_ serverEnvironment: ServerEnvironment) {
    }
}

class CapturingScheduler: Scheduling {
    var notifyDataChangedCalled = false

    func notifyDataChanged() {
        notifyDataChangedCalled = true
    }

    func notifyAppLifecycleEvent() {
    }

    func requestSyncImmediately() {
    }

    func cancelSyncAndSuspendSyncQueue() {
    }

    func resumeSyncQueue() {
    }
}

struct MockRemoteConnecting: RemoteConnecting {
    var code: String = ""

    func pollForRecoveryKey() async throws -> SyncCode.RecoveryKey? {
        return nil
    }

    func stopPolling() {
    }
}

struct MockPersistor: AppearancePreferencesPersistor {

    var homeButtonPosition: HomeButtonPosition = .hidden

    var showFullURL: Bool = false

    var showAutocompleteSuggestions: Bool = false

    var currentThemeName: String = ""

    var defaultPageZoom: CGFloat = 1.0

    var favoritesDisplayMode: String?

    var isFavoriteVisible: Bool = true

    var isContinueSetUpVisible: Bool = true

    var isRecentActivityVisible: Bool = true

    var showBookmarksBar: Bool = false

    var bookmarksBarAppearance: BookmarksBarAppearance = .alwaysOn

}
