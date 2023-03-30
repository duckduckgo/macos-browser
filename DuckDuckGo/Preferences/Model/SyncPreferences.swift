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

    var recoveryCode: String? {
        syncService.account?.recoveryCode
    }

    func presentEnableSyncDialog() {
        presentDialog(for: .enableSync)
    }

    func presentRecoverSyncAccountDialog() {
        presentDialog(for: .recoverAccount)
    }

    func turnOffSync() {
        Task { @MainActor in
            do {
                try await syncService.disconnect()
            } catch {
                errorMessage = String(describing: error)
            }
        }
    }

    init(syncService: DDGSyncing) {
        self.syncService = syncService
        self.managementDialogModel = ManagementDialogModel()
        self.managementDialogModel.delegate = self
        updateState()

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
        managementDialogModel.recoveryCode = syncService.account?.recoveryCode

        if let account = syncService.account {
            devices = [.init(account)]
        } else {
            devices = []
        }
    }

    private func presentDialog(for currentDialog: ManagementDialogKind, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
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
            guard let window = syncWindowController.window, let sheetParent = window.sheetParent else {
                assertionFailure("window or sheet parent not present")
                return
            }
            sheetParent.endSheet(window)
        }

        parentWindowController.window?.beginSheet(syncWindow, completionHandler: handler)
    }

    private var onEndFlow: () -> Void = {}

    private let syncService: DDGSyncing
    private var cancellables = Set<AnyCancellable>()
}

extension SyncPreferences: ManagementDialogModelDelegate {

    private func deviceInfo() -> (name: String, type: String) {
        let hostname = SCDynamicStoreCopyComputerName(nil, nil) as? String ?? ProcessInfo.processInfo.hostName
        return (name: hostname, type: "desktop")
    }

    @MainActor
    private func login(_ recoveryKey: SyncCode.RecoveryKey) async throws {
        let device = deviceInfo()
        try await syncService.login(recoveryKey, deviceName: device.name, deviceType: device.type)
        managementDialogModel.endFlow()
    }

    func turnOnSync() {
        presentDialog(for: .askToSyncAnotherDevice)
    }

    func dontSyncAnotherDeviceNow() {
        Task { @MainActor in
            do {
                let device = deviceInfo()
                try await syncService.createAccount(deviceName: device.name, deviceType: device.type)
            } catch {
                managementDialogModel.errorMessage = String(describing: error)
            }
        }
    }

    func recoverDevice(using recoveryCode: String) {
        Task { @MainActor in
            do {
                guard let recoveryKey = try? SyncCode.decodeBase64String(recoveryCode).recovery else {
                    managementDialogModel.errorMessage = "Invalid recovery key"
                    return
                }

                try await login(recoveryKey)
            } catch {
                managementDialogModel.errorMessage = String(describing: error)
            }
        }
    }

    func presentSyncAnotherDeviceDialog() {
        Task { @MainActor in
            do {
                var running = true
                let connect = try syncService.remoteConnect()
                managementDialogModel.connectCode = connect.code
                presentDialog(for: .syncAnotherDevice) { _ in
                    running = false
                }

                let device = self.deviceInfo()
                while running {
                    if let recoveryKey = try await connect.fetchRecoveryKey() {
                        try await login(recoveryKey)
                        running = false
                    }

                    if running {
                        try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                    }
                }                
                managementDialogModel.endFlow()
            } catch {
                managementDialogModel.errorMessage = String(describing: error)
            }
        }
    }

    func addAnotherDevice() {
        presentDialog(for: .deviceSynced)
    }

    func confirmSetupComplete() {
        presentDialog(for: .saveRecoveryPDF)
    }

    func saveRecoveryPDF() {
        managementDialogModel.endFlow()
    }

}
