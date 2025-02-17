//
//  SyncPreferences.swift
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
import DDGSync
import Combine
import Common
import SystemConfiguration
import SyncUI_macOS
import SwiftUI
import PDFKit
import Navigation
import PixelKit
import os.log
import BrowserServicesKit

extension SyncDevice {
    init(_ account: SyncAccount) {
        self.init(kind: .current, name: account.deviceName, id: account.deviceId)
    }

    init(_ device: RegisteredDevice) {
        let kind: Kind = device.type == "desktop" ? .desktop : .mobile
        self.init(kind: kind, name: device.name, id: device.id)
    }
}

final class SyncPreferences: ObservableObject, SyncUI_macOS.ManagementViewModel {
    var syncPausedTitle: String? {
        return syncPausedStateManager.syncPausedMessageData?.title
    }

    var syncPausedMessage: String? {
        return syncPausedStateManager.syncPausedMessageData?.description
    }

    var syncPausedButtonTitle: String? {
        return syncPausedStateManager.syncPausedMessageData?.buttonTitle
    }

    var syncPausedButtonAction: (() -> Void)? {
        return syncPausedStateManager.syncPausedMessageData?.action
    }

    var syncBookmarksPausedTitle: String? {
        return syncPausedStateManager.syncBookmarksPausedMessageData?.title
    }

    var syncBookmarksPausedMessage: String? {
        return syncPausedStateManager.syncBookmarksPausedMessageData?.description
    }

    var syncBookmarksPausedButtonTitle: String? {
        return syncPausedStateManager.syncBookmarksPausedMessageData?.buttonTitle
    }

    var syncBookmarksPausedButtonAction: (() -> Void)? {
        return syncPausedStateManager.syncBookmarksPausedMessageData?.action
    }

    var syncCredentialsPausedTitle: String? {
        return syncPausedStateManager.syncCredentialsPausedMessageData?.title
    }

    var syncCredentialsPausedMessage: String? {
        return syncPausedStateManager.syncCredentialsPausedMessageData?.description
    }

    var syncCredentialsPausedButtonTitle: String? {
        return syncPausedStateManager.syncCredentialsPausedMessageData?.buttonTitle
    }

    var syncCredentialsPausedButtonAction: (() -> Void)? {
        return syncPausedStateManager.syncCredentialsPausedMessageData?.action
    }

    struct Consts {
        static let syncPausedStateChanged = Notification.Name("com.duckduckgo.app.SyncPausedStateChanged")
    }

    var isSyncEnabled: Bool {
        syncService.account != nil
    }

    @Published var codeToDisplay: String?
    let managementDialogModel: ManagementDialogModel

    @Published var devices: [SyncDevice] = [] {
        didSet {
            syncBookmarksAdapter.isEligibleForFaviconsFetcherOnboarding = devices.count > 1
        }
    }

    @Published var shouldShowErrorMessage: Bool = false
    @Published private(set) var syncErrorMessage: SyncErrorMessage?

    @Published var isCreatingAccount: Bool = false

    @Published var isFaviconsFetchingEnabled: Bool {
        didSet {
            syncBookmarksAdapter.isFaviconsFetchingEnabled = isFaviconsFetchingEnabled
            if isFaviconsFetchingEnabled {
                syncService.scheduler.notifyDataChanged()
            }
        }
    }

    @Published var isUnifiedFavoritesEnabled: Bool {
        didSet {
            appearancePreferences.favoritesDisplayMode = isUnifiedFavoritesEnabled ? .displayUnified(native: .desktop) : .displayNative(.desktop)
            if shouldRequestSyncOnFavoritesOptionChange {
                syncService.scheduler.notifyDataChanged()
            } else {
                shouldRequestSyncOnFavoritesOptionChange = true
            }
        }
    }

    @Published var isSyncPaused: Bool = false
    @Published var isSyncBookmarksPaused: Bool = false
    @Published var isSyncCredentialsPaused: Bool = false

    @Published var invalidBookmarksTitles: [String] = []
    @Published var invalidCredentialsTitles: [String] = []

    private var shouldRequestSyncOnFavoritesOptionChange: Bool = true
    private var isScreenLocked: Bool = false
    private var recoveryKey: SyncCode.RecoveryKey?

    @Published var syncFeatureFlags: SyncFeatureFlags {
        didSet {
            updateSyncFeatureFlags(syncFeatureFlags)
        }
    }

    @Published var isDataSyncingAvailable: Bool = true
    @Published var isConnectingDevicesAvailable: Bool = true
    @Published var isAccountCreationAvailable: Bool = true
    @Published var isAccountRecoveryAvailable: Bool = true
    @Published var isAppVersionNotSupported: Bool = true

    private let syncPausedStateManager: any SyncPausedStateManaging

    private func updateSyncFeatureFlags(_ syncFeatureFlags: SyncFeatureFlags) {
        isDataSyncingAvailable = syncFeatureFlags.contains(.dataSyncing)
        isConnectingDevicesAvailable = syncFeatureFlags.contains(.connectFlows)
        isAccountCreationAvailable = syncFeatureFlags.contains(.accountCreation)
        isAccountRecoveryAvailable = syncFeatureFlags.contains(.accountRecovery)
        isAppVersionNotSupported = syncFeatureFlags.unavailableReason == .appVersionNotSupported
    }

    var recoveryCode: String? {
        syncService.account?.recoveryCode
    }

    private let featureFlagger: FeatureFlagger

    private let diagnosisHelper: SyncDiagnosisHelper

    init(
        syncService: DDGSyncing,
        syncBookmarksAdapter: SyncBookmarksAdapter,
        syncCredentialsAdapter: SyncCredentialsAdapter,
        appearancePreferences: AppearancePreferences = .shared,
        managementDialogModel: ManagementDialogModel = ManagementDialogModel(),
        userAuthenticator: UserAuthenticating = DeviceAuthenticator.shared,
        syncPausedStateManager: any SyncPausedStateManaging,
        featureFlagger: FeatureFlagger = Application.appDelegate.featureFlagger
    ) {
        self.syncService = syncService
        self.syncBookmarksAdapter = syncBookmarksAdapter
        self.syncCredentialsAdapter = syncCredentialsAdapter
        self.appearancePreferences = appearancePreferences
        self.syncFeatureFlags = syncService.featureFlags
        self.userAuthenticator = userAuthenticator
        self.syncPausedStateManager = syncPausedStateManager
        self.featureFlagger = featureFlagger

        self.isFaviconsFetchingEnabled = syncBookmarksAdapter.isFaviconsFetchingEnabled
        self.isUnifiedFavoritesEnabled = appearancePreferences.favoritesDisplayMode.isDisplayUnified

        self.managementDialogModel = managementDialogModel
        diagnosisHelper = SyncDiagnosisHelper(syncService: syncService)
        self.managementDialogModel.delegate = self

        updateSyncFeatureFlags(self.syncFeatureFlags)
        setUpObservables()
        setUpSyncOptionsObservables(apperancePreferences: appearancePreferences)
        updateSyncPausedState()
    }

    private func updateSyncPausedState() {
        self.isSyncPaused = syncPausedStateManager.isSyncPaused
        self.isSyncBookmarksPaused = syncPausedStateManager.isSyncBookmarksPaused
        self.isSyncCredentialsPaused = syncPausedStateManager.isSyncCredentialsPaused
    }

    private func updateInvalidObjects() {
        invalidBookmarksTitles = syncBookmarksAdapter.provider?
            .fetchDescriptionsForObjectsThatFailedValidation()
            .map { $0.truncated(length: 15) } ?? []

        let invalidCredentialsObjects: [String] = (try? syncCredentialsAdapter.provider?.fetchDescriptionsForObjectsThatFailedValidation()) ?? []
        invalidCredentialsTitles = invalidCredentialsObjects.map({ $0.truncated(length: 15) })
    }

    private func setUpObservables() {
        syncService.featureFlagsPublisher
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: \.syncFeatureFlags, onWeaklyHeld: self)
            .store(in: &cancellables)

        syncService.authStatePublisher
            .removeDuplicates()
            .asVoid()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.updateState()
            }
            .store(in: &cancellables)

        syncService.isSyncInProgressPublisher
            .removeDuplicates()
            .filter { !$0 }
            .asVoid()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.updateInvalidObjects()
            }
            .store(in: &cancellables)

        $syncErrorMessage
            .map { $0 != nil }
            .receive(on: DispatchQueue.main)
            .assign(to: \.shouldShowErrorMessage, onWeaklyHeld: self)
            .store(in: &cancellables)

        managementDialogModel.$currentDialog
            .removeDuplicates()
            .filter { $0 == nil }
            .asVoid()
            .sink { [weak self] _ in
                self?.onEndFlow()
            }
            .store(in: &cancellables)

        syncPausedStateManager.syncPausedChangedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateSyncPausedState()
            }
            .store(in: &cancellables)

        let screenIsLockedPublisher = DistributedNotificationCenter.default
            .publisher(for: .init(rawValue: "com.apple.screenIsLocked"))
            .map { _ in true }
        let screenIsUnlockedPublisher = DistributedNotificationCenter.default
            .publisher(for: .init(rawValue: "com.apple.screenIsUnlocked"))
            .map { _ in false }

        Publishers.Merge(screenIsLockedPublisher, screenIsUnlockedPublisher)
            .receive(on: DispatchQueue.main)
            .assign(to: \.isScreenLocked, onWeaklyHeld: self)
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(launchedFromSyncPromo(_:)),
                                               name: SyncPromoManager.SyncPromoManagerNotifications.didGoToSync,
                                               object: nil)
    }

    @MainActor
    func turnOffSyncPressed() {
        presentDialog(for: .turnOffSync)
    }

    @MainActor
    func presentDeviceDetails(_ device: SyncDevice) {
        presentDialog(for: .deviceDetails(device))
    }

    @MainActor
    func presentRemoveDevice(_ device: SyncDevice) {
        presentDialog(for: .removeDevice(device))
    }

    @MainActor
    func manageBookmarks() {
        guard let mainVC = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController else { return }
        mainVC.showManageBookmarks(self)
    }

    @MainActor
    func manageLogins() {
        guard let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController else { return }
        let navigationViewController = parentWindowController.mainViewController.navigationBarViewController
        navigationViewController.showPasswordManagerPopover(selectedCategory: .allItems, source: .sync)
    }

    private func setUpSyncOptionsObservables(apperancePreferences: AppearancePreferences) {
        syncBookmarksAdapter.$isFaviconsFetchingEnabled
            .removeDuplicates()
            .sink { [weak self] isFaviconsFetchingEnabled in
                guard let self else {
                    return
                }
                if self.isFaviconsFetchingEnabled != isFaviconsFetchingEnabled {
                    self.isFaviconsFetchingEnabled = isFaviconsFetchingEnabled
                }
            }
            .store(in: &cancellables)
        apperancePreferences.$favoritesDisplayMode
            .map(\.isDisplayUnified)
            .sink { [weak self] isUnifiedFavoritesEnabled in
                guard let self else {
                    return
                }
                if self.isUnifiedFavoritesEnabled != isUnifiedFavoritesEnabled {
                    self.shouldRequestSyncOnFavoritesOptionChange = false
                    self.isUnifiedFavoritesEnabled = isUnifiedFavoritesEnabled
                }
            }
            .store(in: &cancellables)

        apperancePreferences.$favoritesDisplayMode
            .map(\.isDisplayUnified)
            .sink { [weak self] isUnifiedFavoritesEnabled in
                guard let self else {
                    return
                }
                if self.isUnifiedFavoritesEnabled != isUnifiedFavoritesEnabled {
                    self.shouldRequestSyncOnFavoritesOptionChange = false
                    self.isUnifiedFavoritesEnabled = isUnifiedFavoritesEnabled
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Private

    private func updateState() {
        managementDialogModel.codeToDisplay = syncService.account?.recoveryCode
        refreshDevices()
    }

    @MainActor
    private func mapDevices(_ registeredDevices: [RegisteredDevice]) {
        guard let deviceId = syncService.account?.deviceId else { return }
        self.devices = registeredDevices.map {
            deviceId == $0.id ? SyncDevice(kind: .current, name: $0.name, id: $0.id) : SyncDevice($0)
        }.sorted(by: { item, _ in
            item.isCurrent
        })
    }

    func refreshDevices() {
        guard !isScreenLocked else {
            Logger.sync.debug("Screen is locked, skipping devices refresh")
            return
        }
        guard syncService.account != nil else {
            devices = []
            return
        }
        Task { @MainActor in
            do {
                let registeredDevices = try await syncService.fetchDevices()
                mapDevices(registeredDevices)
            } catch {
                if case SyncError.unauthenticatedWhileLoggedIn = error {
                    // Ruling this out as it's a predictable event likely caused by disabling on another device
                    diagnosisHelper.didManuallyDisableSync()
                }
                PixelKit.fire(DebugEvent(GeneralPixel.syncRefreshDevicesError(error: error), error: error))
                Logger.sync.debug("Failed to refresh devices: \(error)")
            }
        }
    }

    @MainActor
    private func presentDialog(for currentDialog: ManagementDialogKind) {
        let shouldBeginSheet = managementDialogModel.currentDialog == nil
        managementDialogModel.currentDialog = currentDialog

        guard shouldBeginSheet else {
            return
        }

        guard [NSApplication.RunType.normal, .uiTests].contains(NSApp.runType) else {
            return
        }

        let syncViewController = SyncManagementDialogViewController(managementDialogModel)
        let syncWindowController = syncViewController.wrappedInWindowController()

        guard let syncWindow = syncWindowController.window,
              let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController
        else {
            assertionFailure("Sync: Failed to present SyncManagementDialogViewController")
            return
        }

        onEndFlow = {
            self.connector?.stopPolling()
            self.connector = nil

            Task { @MainActor in
                guard let window = syncWindowController.window, let sheetParent = window.sheetParent else {
                    assertionFailure("window or sheet parent not present")
                    return
                }
                sheetParent.endSheet(window)
            }
        }

        parentWindowController.window?.beginSheet(syncWindow)
    }

    @objc
    private func launchedFromSyncPromo(_ sender: Notification) {
        syncPromoSource = sender.userInfo?[SyncPromoManager.Constants.syncPromoSourceKey] as? String
    }

    private var onEndFlow: () -> Void = {}

    private let syncService: DDGSyncing
    private let syncBookmarksAdapter: SyncBookmarksAdapter
    private let syncCredentialsAdapter: SyncCredentialsAdapter
    private let appearancePreferences: AppearancePreferences
    private var cancellables = Set<AnyCancellable>()
    private var connector: RemoteConnecting?
    private let userAuthenticator: UserAuthenticating
    private var syncPromoSource: String?
}

extension SyncPreferences: ManagementDialogModelDelegate {

    func turnOffSync() {
        Task { @MainActor in
            do {
                try await syncService.disconnect()
                managementDialogModel.endFlow()
                syncPausedStateManager.syncDidTurnOff()
                diagnosisHelper.didManuallyDisableSync()
            } catch {
                managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .unableToTurnSyncOff, description: error.localizedDescription)
                PixelKit.fire(DebugEvent(GeneralPixel.syncLogoutError(error: error)))
            }
        }
    }

    func deleteAccount() {
        Task { @MainActor in
            do {
                try await syncService.deleteAccount()
                managementDialogModel.endFlow()
                syncPausedStateManager.syncDidTurnOff()
                diagnosisHelper.didManuallyDisableSync()
            } catch {
                managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .unableToDeleteData, description: error.localizedDescription)
                PixelKit.fire(DebugEvent(GeneralPixel.syncDeleteAccountError(error: error)))
            }
        }
    }

    func updateDeviceName(_ name: String) {
        Task { @MainActor in
            self.devices = []
            syncService.scheduler.cancelSyncAndSuspendSyncQueue()
            do {
                let devices = try await syncService.updateDeviceName(name)
                managementDialogModel.endFlow()
                mapDevices(devices)
            } catch {
                if case SyncError.unauthenticatedWhileLoggedIn = error {
                    // Ruling this out as it's a predictable event likely caused by disabling on another device
                    diagnosisHelper.didManuallyDisableSync()
                }
                managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .unableToUpdateDeviceName, description: error.localizedDescription)
                PixelKit.fire(DebugEvent(GeneralPixel.syncUpdateDeviceError(error: error)))
            }
            syncService.scheduler.resumeSyncQueue()
        }
    }

    private func deviceInfo() -> (name: String, type: String) {
        let hostname = SCDynamicStoreCopyComputerName(nil, nil) as? String ?? ProcessInfo.processInfo.hostName
        return (name: hostname, type: "desktop")
    }

    @MainActor
    private func loginAndShowPresentedDialog(_ recoveryKey: SyncCode.RecoveryKey, isRecovery: Bool) async throws {
        let device = deviceInfo()
        let devices = try await syncService.login(recoveryKey, deviceName: device.name, deviceType: device.type)
        mapDevices(devices)
        PixelKit.fire(GeneralPixel.syncLogin)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if isRecovery {
                self.showDevicesSynced()
            } else {
                self.presentDialog(for: .saveRecoveryCode(self.recoveryCode ?? ""))
            }
            self.stopPollingForRecoveryKey()
        }
    }

    func turnOnSync() {
        Task { @MainActor in
            managementDialogModel.endFlow()
            isCreatingAccount = true
            defer {
                isCreatingAccount = false
            }
            do {
                let device = deviceInfo()
                presentDialog(for: .prepareToSync)
                try await syncService.createAccount(deviceName: device.name, deviceType: device.type)
                let additionalParameters = syncPromoSource.map { ["source": $0] } ?? [:]
                PixelKit.fire(GeneralPixel.syncSignupDirect, withAdditionalParameters: additionalParameters)
                presentDialog(for: .saveRecoveryCode(recoveryCode ?? ""))
            } catch {
                managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .unableToSyncToServer, description: error.localizedDescription)
                PixelKit.fire(DebugEvent(GeneralPixel.syncSignupError(error: error)))
            }
        }
    }

    func startPollingForRecoveryKey(isRecovery: Bool) {
        Task { @MainActor in
            do {
                self.connector = try syncService.remoteConnect()
                self.codeToDisplay = connector?.code
                if isRecovery {
                    self.presentDialog(for: .enterRecoveryCode(code: codeToDisplay ?? ""))
                } else {
                    self.presentDialog(for: .syncWithAnotherDevice(code: codeToDisplay ?? ""))
                }
                if let recoveryKey = try await connector?.pollForRecoveryKey() {
                    presentDialog(for: .prepareToSync)
                    self.recoveryKey = recoveryKey
                    try await loginAndShowPresentedDialog(recoveryKey, isRecovery: isRecovery)
                } else {
                    // Polling was likeley cancelled elsewhere (e.g. dialog closed)
                    return
                }
            } catch {
                if syncService.account == nil {
                    if isRecovery {
                        managementDialogModel.syncErrorMessage = SyncErrorMessage(
                            type: .unableToSyncToServer,
                            description: error.localizedDescription
                        )
                    } else {
                        managementDialogModel.syncErrorMessage = SyncErrorMessage(
                            type: .unableToSyncToOtherDevice,
                            description: error.localizedDescription
                        )
                    }
                    PixelKit.fire(DebugEvent(GeneralPixel.syncLoginError(error: error)))
                }
            }
        }
    }

    func stopPollingForRecoveryKey() {
        self.connector?.stopPolling()
        self.connector = nil
    }

    func recoverDevice(recoveryCode: String, fromRecoveryScreen: Bool) {
        Task { @MainActor in
            guard let syncCode = try? SyncCode.decodeBase64String(recoveryCode) else {
                managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .invalidCode, description: "")
                return
            }
            presentDialog(for: .prepareToSync)
            if let recoveryKey = syncCode.recovery {
                do {
                    try await loginAndShowPresentedDialog(recoveryKey, isRecovery: fromRecoveryScreen)
                } catch {
                    if case SyncError.accountAlreadyExists = error,
                        featureFlagger.isFeatureOn(.syncSeamlessAccountSwitching) {
                        handleAccountAlreadyExists(recoveryKey)
                    } else if case SyncError.accountAlreadyExists = error {
                        managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .unableToMergeTwoAccounts, description: "")
                        PixelKit.fire(DebugEvent(GeneralPixel.syncLoginExistingAccountError(error: error)))
                    } else {
                        managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .unableToSyncToOtherDevice)
                    }
                }
            } else if let connectKey = syncCode.connect {
                do {
                    if syncService.account == nil {
                        let device = deviceInfo()
                        try await syncService.createAccount(deviceName: device.name, deviceType: device.type)
                        let additionalParameters = syncPromoSource.map { ["source": $0] } ?? [:]
                        PixelKit.fire(GeneralPixel.syncSignupConnect, withAdditionalParameters: additionalParameters)
                        presentDialog(for: .saveRecoveryCode(recoveryCode))
                    }

                    try await syncService.transmitRecoveryKey(connectKey)
                    self.$devices
                        .removeDuplicates()
                        .dropFirst()
                        .prefix(1)
                        .sink { [weak self] _ in
                            guard let self else { return }
                            self.presentDialog(for: .saveRecoveryCode(recoveryCode))
                        }.store(in: &cancellables)
                    // The UI will update when the devices list changes.
                } catch {
                    managementDialogModel.syncErrorMessage = SyncErrorMessage(
                        type: .unableToSyncToOtherDevice,
                        description: error.localizedDescription
                    )
                    PixelKit.fire(DebugEvent(GeneralPixel.syncLoginError(error: error)))
                }
            } else {
                managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .invalidCode, description: "")
                return
            }
        }
    }

    @MainActor
    func presentDeleteAccount() {
        presentDialog(for: .deleteAccount(devices))
    }

    @MainActor
    func saveRecoveryPDF() {
        guard let recoveryCode = syncService.account?.recoveryCode else {
            assertionFailure()
            return
        }

        Task { @MainActor in
            let authenticationResult = await userAuthenticator.authenticateUser(reason: .syncSettings)
            guard authenticationResult.authenticated else {
                if authenticationResult == .noAuthAvailable {
                    presentDialog(for: .empty)
                    managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .unableToAuthenticateOnDevice, description: "")
                }
                return
            }

            let data = RecoveryPDFGenerator()
                .generate(recoveryCode)

            let panel = NSSavePanel.savePanelWithFileTypeChooser(fileTypes: [.pdf], suggestedFilename: "Sync Data Recovery - DuckDuckGo.pdf")
            let response = await panel.begin()

            guard response == .OK,
                  let location = panel.url else { return }

            do {
                try Progress.withPublishedProgress(url: location) {
                    try data.write(to: location)
                }
            } catch {
                managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .unableCreateRecoveryPDF, description: error.localizedDescription)
                PixelKit.fire(DebugEvent(GeneralPixel.syncCannotCreateRecoveryPDF))
            }
        }

    }

    @MainActor
    func removeDevice(_ device: SyncDevice) {
        Task { @MainActor in
            do {
                try await syncService.disconnect(deviceId: device.id)
                refreshDevices()
                managementDialogModel.endFlow()
            } catch {
                managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .unableToRemoveDevice, description: error.localizedDescription)
                PixelKit.fire(DebugEvent(GeneralPixel.syncRemoveDeviceError(error: error)))
            }
        }
    }

    @MainActor
    func enterRecoveryCodePressed() {
        startPollingForRecoveryKey(isRecovery: true)
    }

    @MainActor
    func syncWithAnotherDevicePressed() async {
        let authenticationResult = await userAuthenticator.authenticateUser(reason: .syncSettings)
        guard authenticationResult.authenticated else {
            if authenticationResult == .noAuthAvailable {
                presentDialog(for: .empty)
                managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .unableToAuthenticateOnDevice, description: "")
            }
            return
        }
        if isSyncEnabled {
            presentDialog(for: .syncWithAnotherDevice(code: recoveryCode ?? ""))
        } else {
            self.startPollingForRecoveryKey(isRecovery: false)
        }
    }

    @MainActor
    func syncWithServerPressed() async {
        let authenticationResult = await userAuthenticator.authenticateUser(reason: .syncSettings)
        guard authenticationResult.authenticated else {
            if authenticationResult == .noAuthAvailable {
                presentDialog(for: .empty)
                managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .unableToAuthenticateOnDevice, description: "")
            }
            return
        }
        presentDialog(for: .syncWithServer)
    }

    @MainActor
    func recoverDataPressed() async {
        let authenticationResult = await userAuthenticator.authenticateUser(reason: .syncSettings)
        guard authenticationResult.authenticated else {
            if authenticationResult == .noAuthAvailable {
                presentDialog(for: .empty)
                managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .unableToAuthenticateOnDevice, description: "")
            }
            return
        }
        presentDialog(for: .recoverSyncedData)
    }

    @MainActor
    func copyCode() {
        var code: String?
        if isSyncEnabled {
            code = recoveryCode
        } else {
            code = codeToDisplay
        }
        guard let code else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(code, forType: .string)
    }

    @MainActor
    func recoveryCodeNextPressed() {
        showDevicesSynced()
    }

    @MainActor
    func openSystemPasswordSettings() {
        NSWorkspace.shared.open(URL.touchIDAndPassword)
    }

    @MainActor
    private func showDevicesSynced() {
        presentDialog(for: .nowSyncing)
    }

    func recoveryCodePasted(_ code: String) {
        recoverDevice(recoveryCode: code, fromRecoveryScreen: true)
    }

    func recoveryCodePasted(_ code: String, fromRecoveryScreen: Bool) {
        recoverDevice(recoveryCode: code, fromRecoveryScreen: fromRecoveryScreen)
    }

    private func handleAccountAlreadyExists(_ recoveryKey: SyncCode.RecoveryKey) {
        Task { @MainActor in
            if devices.count > 1 {
                managementDialogModel.showSwitchAccountsMessage()
                PixelKit.fire(SyncSwitchAccountPixelKitEvent.syncAskUserToSwitchAccount.withoutMacPrefix)
            } else {
                await switchAccounts(recoveryKey: recoveryKey)
                managementDialogModel.endFlow()
            }
            PixelKit.fire(DebugEvent(GeneralPixel.syncLoginExistingAccountError(error: SyncError.accountAlreadyExists)))
        }
    }

    func userConfirmedSwitchAccounts(recoveryCode: String) {
        PixelKit.fire(SyncSwitchAccountPixelKitEvent.syncUserAcceptedSwitchingAccount.withoutMacPrefix)
        guard let recoveryKey = try? SyncCode.decodeBase64String(recoveryCode).recovery else {
            return
        }
        Task {
            await switchAccounts(recoveryKey: recoveryKey)
            await managementDialogModel.endFlow()
        }
    }

    private func switchAccounts(recoveryKey: SyncCode.RecoveryKey) async {
        do {
            try await syncService.disconnect()
        } catch {
            PixelKit.fire(SyncSwitchAccountPixelKitEvent.syncUserSwitchedLogoutError.withoutMacPrefix)
        }

        do {
            let device = deviceInfo()
            let registeredDevices = try await syncService.login(recoveryKey, deviceName: device.name, deviceType: device.type)
            await mapDevices(registeredDevices)
        } catch {
            PixelKit.fire(SyncSwitchAccountPixelKitEvent.syncUserSwitchedLoginError.withoutMacPrefix)
        }
        PixelKit.fire(SyncSwitchAccountPixelKitEvent.syncUserSwitchedAccount.withoutMacPrefix)
    }

    func switchAccountsCancelled() {
        PixelKit.fire(SyncSwitchAccountPixelKitEvent.syncUserCancelledSwitchingAccount.withoutMacPrefix)
    }
}
