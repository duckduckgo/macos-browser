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

    var isSyncEnabled: Bool {
        syncService.account != nil
    }

    let managementDialogModel: ManagementDialogModel

    @Published var devices: [SyncDevice] = []

    @Published var shouldShowErrorMessage: Bool = false
    @Published private(set) var errorMessage: String?

    @Published var isCreatingAccount: Bool = false

    var recoveryCode: String? {
        syncService.account?.recoveryCode
    }

    @MainActor
    func presentEnableSyncDialog() {
        presentDialog(for: .enableSync)
    }

    @MainActor
    func presentRecoverSyncAccountDialog() {
        presentDialog(for: .recoverAccount)
    }

    @MainActor
    func presentTurnOffSyncConfirmDialog() {
        presentDialog(for: .turnOffSync)
    }

    @MainActor
    func presentShowOrEnterCodeDialog() {
        Task { @MainActor in
            self.$devices
                .removeDuplicates()
                .dropFirst()
                .prefix(1)
                .sink { [weak self] value in
                    self?.presentDialog(for: .deviceSynced(value.filter { !$0.isCurrent }))
                    self?.objectWillChange.send()
                }.store(in: &cancellables)
            managementDialogModel.codeToDisplay = syncService.account?.recoveryCode
            presentDialog(for: .syncAnotherDevice)
        }
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
            } catch {
                errorMessage = String(describing: error)
            }
        }
    }

    init(syncService: DDGSyncing) {
        self.syncService = syncService
        self.managementDialogModel = ManagementDialogModel()
        self.managementDialogModel.delegate = self

        syncService.isAuthenticatedPublisher
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
        if syncService.account != nil {
            Task { @MainActor in
                do {
                    let registeredDevices = try await syncService.fetchDevices()
                    mapDevices(registeredDevices)
                } catch {
                    print("error", error.localizedDescription)
                }
            }
        } else {
            devices = []
        }
    }

    @MainActor
    private func presentDialog(for currentDialog: ManagementDialogKind) {
        let shouldBeginSheet = managementDialogModel.currentDialog == nil
        managementDialogModel.currentDialog = currentDialog

        guard shouldBeginSheet else {
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
            managementDialogModel.endFlow()
            do {
                try await syncService.deleteAccount()
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
    private func loginAndShowPresentedDialog(_ recoveryKey: SyncCode.RecoveryKey) async throws {
        let device = deviceInfo()
        let knownDevices = Set(self.devices.map { $0.id })
        let devices = try await syncService.login(recoveryKey, deviceName: device.name, deviceType: device.type)
        mapDevices(devices)
        let syncedDevices = self.devices.filter { !knownDevices.contains($0.id) && !$0.isCurrent }

        managementDialogModel.endFlow()
        presentDialog(for: .deviceSynced(syncedDevices))
    }

    @MainActor
    func turnOnSync() {
        presentDialog(for: .askToSyncAnotherDevice)
    }

    func dontSyncAnotherDeviceNow() {
        Task { @MainActor in
            isCreatingAccount = true
            defer {
                isCreatingAccount = false
            }
            do {
                let device = deviceInfo()
                try await syncService.createAccount(deviceName: device.name, deviceType: device.type)
                confirmSetupComplete()
            } catch {
                managementDialogModel.errorMessage = String(describing: error)
            }
        }
    }

    func recoverDevice(using recoveryCode: String) {
        Task { @MainActor in
            do {
                guard let syncCode = try? SyncCode.decodeBase64String(recoveryCode) else {
                    managementDialogModel.errorMessage = "Invalid code"
                    return
                }
                if let recoveryKey = syncCode.recovery {
                    // This will error if the account already exists, we don't have good UI for this just now
                    try await loginAndShowPresentedDialog(recoveryKey)
                } else if let connectKey = syncCode.connect {
                    if syncService.account == nil {
                        let device = deviceInfo()
                        try await syncService.createAccount(deviceName: device.name, deviceType: device.type)
                    }

                    try await syncService.transmitRecoveryKey(connectKey)

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

    func presentSyncAnotherDeviceDialog() {
        Task { @MainActor in
            do {
                self.connector = try syncService.remoteConnect()
                managementDialogModel.codeToDisplay = connector?.code
                presentDialog(for: .syncAnotherDevice)
                if let recoveryKey = try await connector?.pollForRecoveryKey() {
                    try await loginAndShowPresentedDialog(recoveryKey)
                } else {
                    // Polling was likeley cancelled elsewhere (e.g. dialog closed)
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
    func confirmSetupComplete() {
        presentDialog(for: .saveRecoveryPDF)
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
                managementDialogModel.endFlow()
                refreshDevices()
            } catch {
                managementDialogModel.errorMessage = String(describing: error)
            }
        }
    }

}
