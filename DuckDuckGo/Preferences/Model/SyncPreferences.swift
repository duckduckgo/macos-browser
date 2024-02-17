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
import SyncUI
import SwiftUI
import PDFKit
import Navigation
import PixelKit

extension SyncDevice {
    init(_ account: SyncAccount) {
        self.init(kind: .current, name: account.deviceName, id: account.deviceId)
    }

    init(_ device: RegisteredDevice) {
        let kind: Kind = device.type == "desktop" ? .desktop : .mobile
        self.init(kind: kind, name: device.name, id: device.id)
    }
}

final class SyncPreferences: ObservableObject, SyncUI.ManagementViewModel {

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

    @Published var isSyncBookmarksPaused: Bool

    @Published var isSyncCredentialsPaused: Bool

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

    init(
        syncService: DDGSyncing,
        syncBookmarksAdapter: SyncBookmarksAdapter,
        appearancePreferences: AppearancePreferences = .shared,
        managementDialogModel: ManagementDialogModel = ManagementDialogModel(),
        userAuthenticator: UserAuthenticating = DeviceAuthenticator.shared
    ) {
        self.syncService = syncService
        self.syncBookmarksAdapter = syncBookmarksAdapter
        self.appearancePreferences = appearancePreferences
        self.syncFeatureFlags = syncService.featureFlags
        self.userAuthenticator = userAuthenticator

        self.isFaviconsFetchingEnabled = syncBookmarksAdapter.isFaviconsFetchingEnabled
        self.isUnifiedFavoritesEnabled = appearancePreferences.favoritesDisplayMode.isDisplayUnified
        isSyncBookmarksPaused = UserDefaultsWrapper(key: .syncBookmarksPaused, defaultValue: false).wrappedValue
        isSyncCredentialsPaused = UserDefaultsWrapper(key: .syncCredentialsPaused, defaultValue: false).wrappedValue

        self.managementDialogModel = managementDialogModel
        self.managementDialogModel.delegate = self

        updateSyncFeatureFlags(self.syncFeatureFlags)
        setUpObservables()
        setUpSyncOptionsObservables(apperancePreferences: appearancePreferences)
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

        NotificationCenter.default.publisher(for: Self.Consts.syncPausedStateChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isSyncBookmarksPaused = UserDefaultsWrapper(key: .syncBookmarksPaused, defaultValue: false).wrappedValue
                self?.isSyncCredentialsPaused = UserDefaultsWrapper(key: .syncCredentialsPaused, defaultValue: false).wrappedValue
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

    func turnOffSync() {
        Task { @MainActor in
            do {
                try await syncService.disconnect()
                managementDialogModel.endFlow()
                UserDefaults.standard.set(false, forKey: UserDefaultsWrapper<Bool>.Key.syncBookmarksPaused.rawValue)
                UserDefaults.standard.set(false, forKey: UserDefaultsWrapper<Bool>.Key.syncCredentialsPaused.rawValue)
            } catch {
                managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .unableToTurnSyncOff, description: error.localizedDescription)
                firePixelIfNeeded(event: .debug(event: .syncLogoutError, error: error))
            }
        }
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
        navigationViewController.showPasswordManagerPopover(selectedCategory: .allItems)
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
            os_log(.debug, log: .sync, "Screen is locked, skipping devices refresh")
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
                os_log(.error, log: .sync, "Failed to refresh devices: \(error)")
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

        guard case .normal = NSApp.runType else {
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

            guard let window = syncWindowController.window, let sheetParent = window.sheetParent else {
                assertionFailure("window or sheet parent not present")
                return
            }
            sheetParent.endSheet(window)
        }

        parentWindowController.window?.beginSheet(syncWindow)
    }

    private var onEndFlow: () -> Void = {}

    private let syncService: DDGSyncing
    private let syncBookmarksAdapter: SyncBookmarksAdapter
    private let appearancePreferences: AppearancePreferences
    private var cancellables = Set<AnyCancellable>()
    private var connector: RemoteConnecting?
    private let userAuthenticator: UserAuthenticating
}

extension SyncPreferences: ManagementDialogModelDelegate {

    func deleteAccount() {
        Task { @MainActor in
            do {
                try await syncService.deleteAccount()
                managementDialogModel.endFlow()
                UserDefaults.standard.set(false, forKey: UserDefaultsWrapper<Bool>.Key.syncBookmarksPaused.rawValue)
                UserDefaults.standard.set(false, forKey: UserDefaultsWrapper<Bool>.Key.syncCredentialsPaused.rawValue)
            } catch {
                managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .unableToDeleteData, description: error.localizedDescription)
                firePixelIfNeeded(event: .debug(event: .syncDeleteAccountError, error: error))
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
                managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .unableToUpdateDeviceName, description: error.localizedDescription)
                firePixelIfNeeded(event: .debug(event: .syncUpdateDeviceError, error: error))
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
        Pixel.fire(.syncLogin)
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
                Pixel.fire(.syncSignupDirect)
                presentDialog(for: .saveRecoveryCode(recoveryCode ?? ""))
            } catch {
                managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .unableToSyncToServer, description: error.localizedDescription)
                firePixelIfNeeded(event: .debug(event: .syncSignupError, error: error))
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
                    firePixelIfNeeded(event: .debug(event: .syncLoginError, error: error))
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
                    managementDialogModel.syncErrorMessage = SyncErrorMessage(type: .unableToMergeTwoAccounts, description: "")
                    firePixelIfNeeded(event: .debug(event: .syncLoginExistingAccountError, error: error))
                }
            } else if let connectKey = syncCode.connect {
                do {
                    if syncService.account == nil {
                        let device = deviceInfo()
                        try await syncService.createAccount(deviceName: device.name, deviceType: device.type)
                        Pixel.fire(.syncSignupConnect)
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
                    firePixelIfNeeded(event: .debug(event: .syncLoginError, error: error))
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

        let data = RecoveryPDFGenerator()
            .generate(recoveryCode)

        Task { @MainActor in
            let authenticationResult = await userAuthenticator.authenticateUser(reason: .syncSettings)
            guard authenticationResult.authenticated else {
                return
            }

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
                firePixelIfNeeded(event: .debug(event: .syncCannotCreateRecoveryPDF, error: nil))
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
                firePixelIfNeeded(event: .debug(event: .syncRemoveDeviceError, error: error))
            }
        }
    }

    @MainActor
    func enterRecoveryCodePressed() {
        startPollingForRecoveryKey(isRecovery: true)
    }

    @MainActor
    func syncWithAnotherDevicePressed() async {
        guard await userAuthenticator.authenticateUser(reason: .syncSettings).authenticated else {
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
        guard await userAuthenticator.authenticateUser(reason: .syncSettings).authenticated else {
            return
        }
        presentDialog(for: .syncWithServer)
    }

    @MainActor
    func recoverDataPressed() async {
        guard await userAuthenticator.authenticateUser(reason: .syncSettings).authenticated else {
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
    private func showDevicesSynced() {
        presentDialog(for: .nowSyncing)
    }

    func recoveryCodePasted(_ code: String) {
        recoverDevice(recoveryCode: code, fromRecoveryScreen: true)
    }

    func recoveryCodePasted(_ code: String, fromRecoveryScreen: Bool) {
        recoverDevice(recoveryCode: code, fromRecoveryScreen: fromRecoveryScreen)
    }

    private func firePixelIfNeeded(event: Pixel.Event) {
        if case let .debug(_, debugError) = event {
            if debugError == nil {
                Pixel.fire(event)
            }
            if let syncError = debugError as? SyncError, !syncError.isServerError {
                Pixel.fire(event, withAdditionalParameters: syncError.errorParameters)
            }
        }
    }

}
