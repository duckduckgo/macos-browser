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
import SystemConfiguration
import SyncUI
import SwiftUI
import PDFKit
import Navigation

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

    @Published var devices: [SyncDevice] = []

    @Published var shouldShowErrorMessage: Bool = false
    @Published private(set) var errorMessage: String?

    @Published var isCreatingAccount: Bool = false

    @Published var isUnifiedFavoritesEnabled: Bool {
        didSet {
            AppearancePreferences.shared.favoritesDisplayMode = isUnifiedFavoritesEnabled ? .displayUnified(native: .desktop) : .displayNative(.desktop)
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

    private var recoveryKey: SyncCode.RecoveryKey?

    var recoveryCode: String? {
        syncService.account?.recoveryCode
    }

    init(syncService: DDGSyncing, apperancePreferences: AppearancePreferences = .shared, managementDialogModel: ManagementDialogModel = ManagementDialogModel()) {
        self.syncService = syncService

        self.isUnifiedFavoritesEnabled = apperancePreferences.favoritesDisplayMode.isDisplayUnified
        isSyncBookmarksPaused = UserDefaultsWrapper(key: .syncBookmarksPaused, defaultValue: false).wrappedValue
        isSyncCredentialsPaused = UserDefaultsWrapper(key: .syncCredentialsPaused, defaultValue: false).wrappedValue

        self.managementDialogModel = managementDialogModel
        self.managementDialogModel.delegate = self

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

        syncService.authStatePublisher
            .removeDuplicates()
            .asVoid()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.updateState()
            }
            .store(in: &cancellables)

        $errorMessage
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
                errorMessage = String(describing: error)
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
        guard let navigationViewController = parentWindowController.mainViewController.navigationBarViewController else { return }
        navigationViewController.showPasswordManagerPopover(selectedCategory: .allItems)
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
        guard syncService.account != nil else {
            devices = []
            return
        }
        Task { @MainActor in
            do {
                let registeredDevices = try await syncService.fetchDevices()
                mapDevices(registeredDevices)
            } catch {
                print("error", error.localizedDescription)
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
    private var cancellables = Set<AnyCancellable>()
    private var connector: RemoteConnecting?
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
                managementDialogModel.errorMessage = String(describing: error)
            }
        }
    }

    func updateDeviceName(_ name: String) {
        Task { @MainActor in
            do {
                self.devices = []
                let devices = try await syncService.updateDeviceName(name)
                mapDevices(devices)
            } catch {
                managementDialogModel.errorMessage = String(describing: error)
            }
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
        if isRecovery {
            showDevicesSynced()
        } else {
            presentDialog(for: .saveRecoveryCode(recoveryCode ?? ""))
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
                presentDialog(for: .saveRecoveryCode(recoveryCode ?? ""))
            } catch {
                managementDialogModel.errorMessage = String(describing: error)
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
                    if isRecovery {
                        presentDialog(for: .yourDataIsReturning)
                    } else {
                        presentDialog(for: .prepareToSync)
                    }
                    self.recoveryKey = recoveryKey
                    try await loginAndShowPresentedDialog(recoveryKey, isRecovery: isRecovery)
                    stopPollingForRecoveryKey()
                } else {
                    // Polling was likeley cancelled elsewhere (e.g. dialog closed)
                    return
                }
            } catch {
                if syncService.account == nil {
                    managementDialogModel.errorMessage = String(describing: error)
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
            do {
                guard let syncCode = try? SyncCode.decodeBase64String(recoveryCode) else {
                    managementDialogModel.errorMessage = "Invalid code"
                    return
                }
                if fromRecoveryScreen {
                    presentDialog(for: .yourDataIsReturning)
                } else {
                    presentDialog(for: .prepareToSync)
                }
                if let recoveryKey = syncCode.recovery {
                    // This will error if the account already exists, we don't have good UI for this just now
                    try await loginAndShowPresentedDialog(recoveryKey, isRecovery: fromRecoveryScreen)
                } else if let connectKey = syncCode.connect {
                    if syncService.account == nil {
                        let device = deviceInfo()
                        try await syncService.createAccount(deviceName: device.name, deviceType: device.type)
                    }

                    try await syncService.transmitRecoveryKey(connectKey)
                    self.$devices
                        .removeDuplicates()
                        .dropFirst()
                        .prefix(1)
                        .sink { [weak self] devices in
                            guard let self else { return }
                            self.presentDialog(for: .nowSyncing)
                        }.store(in: &cancellables)

                    // The UI will update when the devices list changes.
                } else {
                    managementDialogModel.errorMessage = "Invalid code"
                    return
                }
            } catch {
                managementDialogModel.errorMessage = String(describing: error)
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
            let panel = NSSavePanel.savePanelWithFileTypeChooser(fileTypes: [.pdf], suggestedFilename: "DuckDuckGo Recovery Code.pdf")
            let response = await panel.begin()

            guard response == .OK,
                  let location = panel.url else { return }

            do {
                try data.writeFileWithProgress(to: location)
            } catch {
                managementDialogModel.errorMessage = String(describing: error)
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
                managementDialogModel.errorMessage = String(describing: error)
            }
        }
    }

    @MainActor
    func enterRecoveryCodePressed() {
        startPollingForRecoveryKey(isRecovery: true)
    }

    @MainActor
    func syncWithAnotherDevicePressed() {
        if isSyncEnabled {
            presentDialog(for: .syncWithAnotherDevice(code: recoveryCode ?? ""))
        } else {
            self.startPollingForRecoveryKey(isRecovery: false)
        }
    }

    @MainActor
    func syncWithServerPressed() {
        presentDialog(for: .syncWithServer)
    }

    @MainActor
    func recoverDataPressed() {
        presentDialog(for: .recoverSyncedData)
    }

    @MainActor
    func downloadDDGPressed() {

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

}
