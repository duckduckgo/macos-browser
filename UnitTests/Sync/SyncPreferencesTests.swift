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
import SyncUI_macOS
import XCTest
import PersistenceTestingUtils
@testable import BrowserServicesKit
@testable import DDGSync
@testable import DuckDuckGo_Privacy_Browser

private final class MockUserAuthenticator: UserAuthenticating {
    func authenticateUser(reason: DuckDuckGo_Privacy_Browser.DeviceAuthenticator.AuthenticationReason) async -> DeviceAuthenticationResult {
        .success
    }
    func authenticateUser(reason: DeviceAuthenticator.AuthenticationReason, result: @escaping (DeviceAuthenticationResult) -> Void) {
        result(.success)
    }
}

final class SyncPreferencesTests: XCTestCase {

    let scheduler = CapturingScheduler()
    let managementDialogModel = ManagementDialogModel()
    var ddgSyncing: MockDDGSyncing!
    var syncBookmarksAdapter: SyncBookmarksAdapter!
    var syncCredentialsAdapter: SyncCredentialsAdapter!
    var appearancePersistor = MockAppearancePreferencesPersistor()
    var appearancePreferences: AppearancePreferences!
    var syncPreferences: SyncPreferences!
    var pausedStateManager: MockSyncPausedStateManaging!
    var testRecoveryCode = "eyJyZWNvdmVyeSI6eyJ1c2VyX2lkIjoiMDZGODhFNzEtNDFBRS00RTUxLUE2UkRtRkEwOTcwMDE5QkYwIiwicHJpbWFyeV9rZXkiOiI1QTk3U3dsQVI5RjhZakJaU09FVXBzTktnSnJEYnE3aWxtUmxDZVBWazgwPSJ9fQ=="
    var cancellables: Set<AnyCancellable>!

    var bookmarksDatabase: CoreDataDatabase!
    var location: URL!

    override func setUp() {
        cancellables = []
        setUpDatabase()
        appearancePreferences = AppearancePreferences(persistor: appearancePersistor)
        ddgSyncing = MockDDGSyncing(authState: .inactive, scheduler: scheduler, isSyncInProgress: false)
        pausedStateManager = MockSyncPausedStateManaging()

        syncBookmarksAdapter = SyncBookmarksAdapter(database: bookmarksDatabase, appearancePreferences: appearancePreferences, syncErrorHandler: SyncErrorHandler())
        syncCredentialsAdapter = SyncCredentialsAdapter(secureVaultFactory: AutofillSecureVaultFactory, syncErrorHandler: SyncErrorHandler())
        let featureFlagger = MockFeatureFlagger()
        featureFlagger.isFeatureOn = true

        syncPreferences = SyncPreferences(
            syncService: ddgSyncing,
            syncBookmarksAdapter: syncBookmarksAdapter,
            syncCredentialsAdapter: syncCredentialsAdapter,
            appearancePreferences: appearancePreferences,
            managementDialogModel: managementDialogModel,
            userAuthenticator: MockUserAuthenticator(),
            syncPausedStateManager: pausedStateManager,
            featureFlagger: featureFlagger
        )
    }

    override func tearDown() {
        ddgSyncing = nil
        syncPreferences = nil
        pausedStateManager = nil
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

    @MainActor func testOnPresentRecoverSyncAccountDialogThenRecoverAccountDialogShown() async {
        await syncPreferences.recoverDataPressed()

        XCTAssertEqual(managementDialogModel.currentDialog, .recoverSyncedData)
    }

    @MainActor func testOnSyncWithServerPressedThenSyncWithServerDialogShown() async {
        await syncPreferences.syncWithServerPressed()

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
        Task { @MainActor in
            syncPreferences.turnOffSync()
            XCTAssertNil(managementDialogModel.currentDialog)
            await Task.yield()
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertTrue(ddgSyncing.disconnectCalled)
    }

    // MARK: - SYNC ERRORS
    @MainActor
    func test_WhenSyncPausedIsTrue_andChangePublished_isSyncPausedIsUpdated() async {
        let expectation2 = XCTestExpectation(description: "isSyncPaused received the update")
        let expectation1 = XCTestExpectation(description: "isSyncPaused published")
        syncPreferences.$isSyncPaused
            .dropFirst()
            .sink { isPaused in
                XCTAssertTrue(isPaused)
                expectation2.fulfill()
            }
            .store(in: &cancellables)

        Task {
            pausedStateManager.isSyncPaused = true
            pausedStateManager.isSyncPausedChangedPublisher.send()
            expectation1.fulfill()
        }

        await self.fulfillment(of: [expectation1, expectation2], timeout: 5.0)
    }

    @MainActor
    func test_WhenSyncBookmarksPausedIsTrue_andChangePublished_isSyncBookmarksPausedIsUpdated() async {
        let expectation2 = XCTestExpectation(description: "isSyncBookmarksPaused received the update")
        let expectation1 = XCTestExpectation(description: "isSyncBookmarksPaused published")
        syncPreferences.$isSyncBookmarksPaused
            .dropFirst()
            .sink { isPaused in
                XCTAssertTrue(isPaused)
                expectation2.fulfill()
            }
            .store(in: &cancellables)

        Task {
            pausedStateManager.isSyncBookmarksPaused = true
            pausedStateManager.isSyncPausedChangedPublisher.send()
            expectation1.fulfill()
        }

        await self.fulfillment(of: [expectation1, expectation2], timeout: 5.0)
    }

    @MainActor
    func test_WhenSyncCredentialsPausedIsTrue_andChangePublished_isSyncCredentialsPausedIsUpdated() async {
        let expectation2 = XCTestExpectation(description: "isSyncCredentialsPaused received the update")
        let expectation1 = XCTestExpectation(description: "isSyncCredentialsPaused published")
        syncPreferences.$isSyncCredentialsPaused
            .dropFirst()
            .sink { isPaused in
                XCTAssertTrue(isPaused)
                expectation2.fulfill()
            }
            .store(in: &cancellables)

        Task {
            pausedStateManager.isSyncCredentialsPaused = true
            pausedStateManager.isSyncPausedChangedPublisher.send()
            expectation1.fulfill()
        }

        await self.fulfillment(of: [expectation1, expectation2], timeout: 5.0)
    }

    @MainActor
    func test_WhenSyncIsTurnedOff_ErrorHandlerSyncDidTurnOffCalled() async {
        let expectation = XCTestExpectation(description: "Sync Turned off")

        Task { @MainActor in
            syncPreferences.turnOffSync()
            await Task.yield()
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertTrue(pausedStateManager.syncDidTurnOffCalled)
    }

    @MainActor
    func test_WhenAccountRemoved_ErrorHandlerSyncDidTurnOffCalled() async {
        let expectation = XCTestExpectation(description: "Sync Turned off")

        Task {
            syncPreferences.deleteAccount()
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertTrue(pausedStateManager.syncDidTurnOffCalled)
    }

    func test_ErrorHandlerReturnsExpectedSyncBookmarksPausedMetadata() {
        XCTAssertEqual(syncPreferences.syncBookmarksPausedTitle, MockSyncPausedStateManaging.syncBookmarksPausedData.title)
        XCTAssertEqual(syncPreferences.syncBookmarksPausedMessage, MockSyncPausedStateManaging.syncBookmarksPausedData.description)
        XCTAssertEqual(syncPreferences.syncBookmarksPausedButtonTitle, MockSyncPausedStateManaging.syncBookmarksPausedData.buttonTitle)
        XCTAssertNotNil(syncPreferences.syncBookmarksPausedButtonAction)
    }

    func test_ErrorHandlerReturnsExpectedSyncCredentialsPausedMetadata() {
        XCTAssertEqual(syncPreferences.syncCredentialsPausedTitle, MockSyncPausedStateManaging.syncCredentialsPausedData.title)
        XCTAssertEqual(syncPreferences.syncCredentialsPausedMessage, MockSyncPausedStateManaging.syncCredentialsPausedData.description)
        XCTAssertEqual(syncPreferences.syncCredentialsPausedButtonTitle, MockSyncPausedStateManaging.syncCredentialsPausedData.buttonTitle)
        XCTAssertNotNil(syncPreferences.syncCredentialsPausedButtonAction)
    }

    func test_ErrorHandlerReturnsExpectedSyncIsPausedMetadata() {
        XCTAssertEqual(syncPreferences.syncPausedTitle, MockSyncPausedStateManaging.syncIsPausedData.title)
        XCTAssertEqual(syncPreferences.syncPausedMessage, MockSyncPausedStateManaging.syncIsPausedData.description)
        XCTAssertEqual(syncPreferences.syncPausedButtonTitle, MockSyncPausedStateManaging.syncIsPausedData.buttonTitle)
        XCTAssertNil(syncPreferences.syncPausedButtonAction)
    }

    func test_recoverDevice_accountAlreadyExists_oneDevice_disconnectsThenLogsInAgain() async {
        // Must have an account to prevent devices being cleared
        setUpWithSingleDevice(id: "1")
        let firstLoginCalledExpectation = XCTestExpectation(description: "Login Called Once")
        let secondLoginCalledExpectation = XCTestExpectation(description: "Login Called Again")

        ddgSyncing.spyLogin = { [weak self] _, _, _ in
            self?.ddgSyncing.spyLogin = { [weak self] _, _, _ in
                guard let self else { return [] }
                // Assert disconnect before returning from login to ensure correct order
                XCTAssert(ddgSyncing.disconnectCalled)
                secondLoginCalledExpectation.fulfill()
                return [RegisteredDevice(id: "1", name: "iPhone", type: "iPhone"), RegisteredDevice(id: "2", name: "Macbook Pro", type: "Macbook Pro")]
            }
            firstLoginCalledExpectation.fulfill()
            throw SyncError.accountAlreadyExists
        }

        syncPreferences.recoverDevice(recoveryCode: testRecoveryCode, fromRecoveryScreen: false)

        await fulfillment(of: [firstLoginCalledExpectation, secondLoginCalledExpectation], timeout: 5.0)
    }

    func test_recoverDevice_accountAlreadyExists_oneDevice_updatesDevicesWithReturnedDevices() async throws {
        // Must have an account to prevent devices being cleared
        setUpWithSingleDevice(id: "1")

        ddgSyncing.spyLogin = { [weak self] _, _, _ in
            self?.ddgSyncing.spyLogin = { _, _, _ in
                return [RegisteredDevice(id: "1", name: "iPhone", type: "iPhone"), RegisteredDevice(id: "2", name: "Macbook Pro", type: "Macbook Pro")]
            }
            throw SyncError.accountAlreadyExists
        }

        syncPreferences.recoverDevice(recoveryCode: testRecoveryCode, fromRecoveryScreen: false)

        let deviceIDsPublisher = syncPreferences.$devices.map { $0.map { $0.id } }
        _ = try await waitForPublisher(deviceIDsPublisher, timeout: 15.0, toEmit: ["1", "2"])
    }

    func test_recoverDevice_accountAlreadyExists_oneDevice_endsFlow() async throws {
        setUpWithSingleDevice(id: "1")
        // Removal of currentDialog indicates end of flow
        managementDialogModel.currentDialog = .enterRecoveryCode(code: "")
        let loginCalledExpectation = XCTestExpectation(description: "Login Called Once")
        let secondLoginCalledExpectation = XCTestExpectation(description: "Login Called Again")

        ddgSyncing.spyLogin = { [weak self] _, _, _ in
            self?.ddgSyncing.spyLogin = { _, _, _ in
                return [RegisteredDevice(id: "1", name: "iPhone", type: "iPhone"), RegisteredDevice(id: "2", name: "Macbook Pro", type: "Macbook Pro")]
            }
            loginCalledExpectation.fulfill()
            throw SyncError.accountAlreadyExists
        }

        syncPreferences.recoverDevice(recoveryCode: testRecoveryCode, fromRecoveryScreen: false)
        await fulfillment(of: [loginCalledExpectation], timeout: 5.0)

        _ = try await waitForPublisher(managementDialogModel.$currentDialog, timeout: 5.0, toEmit: nil)
    }

    func test_recoverDevice_accountAlreadyExists_twoOrMoreDevices_showsAccountSwitchingMessage() async throws {
        // Must have an account to prevent devices being cleared
        ddgSyncing.account = SyncAccount(deviceId: "1", deviceName: "", deviceType: "", userId: "", primaryKey: Data(), secretKey: Data(), token: nil, state: .active)
        syncPreferences.devices = [SyncDevice(RegisteredDevice(id: "1", name: "iPhone", type: "iPhone")), SyncDevice(RegisteredDevice(id: "2", name: "iPhone", type: "iPhone"))]

        let loginCalledExpectation = XCTestExpectation(description: "Login Called Again")

        ddgSyncing.spyLogin = { _, _, _ in
            loginCalledExpectation.fulfill()
            throw SyncError.accountAlreadyExists
        }

        syncPreferences.recoverDevice(recoveryCode: testRecoveryCode, fromRecoveryScreen: false)

        await fulfillment(of: [loginCalledExpectation], timeout: 5.0)

        XCTAssert(managementDialogModel.shouldShowErrorMessage)
        XCTAssert(managementDialogModel.shouldShowSwitchAccountsMessage)
    }

    func test_switchAccounts_disconnectsThenLogsInAgain() async throws {
        let loginCalledExpectation = XCTestExpectation(description: "Login Called Again")

        ddgSyncing.spyLogin = { [weak self] _, _, _ in
            guard let self else { return [] }
            // Assert disconnect before returning from login to ensure correct order
            XCTAssert(ddgSyncing.disconnectCalled)
            loginCalledExpectation.fulfill()
            return [RegisteredDevice(id: "1", name: "iPhone", type: "iPhone"), RegisteredDevice(id: "2", name: "Macbook Pro", type: "Macbook Pro")]
        }

        syncPreferences.userConfirmedSwitchAccounts(recoveryCode: testRecoveryCode)

        await fulfillment(of: [loginCalledExpectation], timeout: 5.0)
    }

    func test_switchAccounts_updatesDevicesWithReturnedDevices() async throws {
        setUpWithSingleDevice(id: "1")

        ddgSyncing.spyLogin = { _, _, _ in
            return [RegisteredDevice(id: "1", name: "iPhone", type: "iPhone"), RegisteredDevice(id: "2", name: "Macbook Pro", type: "Macbook Pro")]
        }

        syncPreferences.userConfirmedSwitchAccounts(recoveryCode: testRecoveryCode)
        let deviceIDsPublisher = syncPreferences.$devices.map { $0.map { $0.id } }
        try await waitForPublisher(deviceIDsPublisher, toEmit: ["1", "2"])
    }

    private func setUpWithSingleDevice(id: String)  {
        ddgSyncing.account = SyncAccount(deviceId: id, deviceName: "iPhone", deviceType: "iPhone", userId: "", primaryKey: Data(), secretKey: Data(), token: nil, state: .active)
        ddgSyncing.registeredDevices = [RegisteredDevice(id: id, name: "iPhone", type: "iPhone")]
        syncPreferences.devices = [SyncDevice(RegisteredDevice(id: id, name: "iPhone", type: "iPhone"))]
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
