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
                presentDialog(for: .deviceSynced)

            } catch {
                managementDialogModel.errorMessage = String(describing: error)
            }
        }
    }

    func presentSyncAnotherDeviceDialog() {
        Task { @MainActor in
            do {
                self.connector = try syncService.remoteConnect()
                managementDialogModel.connectCode = connector?.code
                presentDialog(for: .syncAnotherDevice)
                if let recoveryKey = try await connector?.pollForRecoveryKey() {
                    try await login(recoveryKey)
                    presentDialog(for: .deviceSynced)
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
    func confirmSetupComplete() {
        presentDialog(for: .saveRecoveryPDF)
    }

    func newPDFLocation() -> String {
        return "/Users/brindy/Downloads/\(UUID().uuidString).pdf"
    }

    @MainActor
    func saveRecoveryPDF() {

        guard let recoveryCode = syncService.account?.recoveryCode else {
            assertionFailure()
            return
        }

        do {
            try RecoveryPDFGenerator
                .generate(recoveryCode)
                .write(to: URL(fileURLWithPath: newPDFLocation()))
        } catch {
            fatalError(error.localizedDescription)
        }

    }

}
