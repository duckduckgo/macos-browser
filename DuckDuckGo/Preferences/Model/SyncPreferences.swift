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
        self.init(kind: .mobile, name: device.name, id: device.id)
    }
}

final class SyncPreferences: ObservableObject {

    var isSyncEnabled: Bool {
        account != nil
    }

    @Published private(set) var currentDialog: SyncManagementDialogKind? {
        didSet {
            if currentDialog == nil && oldValue != nil {
                onEndFlow()
            }
        }
    }

    @Published var account: SyncAccount?
    @Published var devices: [SyncDevice] = []

    @Published var shouldShowErrorMessage: Bool = false
    @Published private(set) var errorMessage: String?

    var recoveryCode: String? {
        account?.recoveryCode
    }

    init(syncService: SyncService = .shared) {
        self.syncService = syncService
        updateState()

        isSyncEnabledCancellable = syncService.sync.isAuthenticatedPublisher
            .removeDuplicates()
            .asVoid()
            .receive(on: DispatchQueue.main)
            .sink { [weak self]  in
                self?.updateState()
            }
    }

    private func updateState() {
        account = syncService.sync.account

        if let account {
            devices = [.init(account)]
        } else {
            devices = []
        }
        if let code = account?.recoveryCode {
            print(code)
        }
    }

    func presentEnableSyncDialog() {
        presentDialog(for: .enableSync)
    }

    func presentRecoverSyncAccountDialog() {
        presentDialog(for: .recoverAccount)
    }

    func presentSyncAnotherDeviceDialog() {
        presentDialog(for: .syncAnotherDevice)
    }

    func turnOnSync() {
        Task { @MainActor in
            do {
//                let hostname = SCDynamicStoreCopyComputerName(nil, nil) as? String ?? ProcessInfo.processInfo.hostName
                let hostname = ProcessInfo.processInfo.hostName
                try await syncService.sync.createAccount(deviceName: hostname)
                presentDialog(for: .askToSyncAnotherDevice)
            } catch {
                errorMessage = String(describing: error)
                shouldShowErrorMessage = true
            }
        }
    }

    func recoverDevice(using recoveryCode: String) {
        Task { @MainActor in
            do {
//                let hostname = SCDynamicStoreCopyComputerName(nil, nil) as? String ?? ProcessInfo.processInfo.hostName
                let hostname = ProcessInfo.processInfo.hostName
                try await syncService.sync.login(recoveryKey: recoveryCode, deviceName: hostname)
                endFlow()
            } catch {
                errorMessage = String(describing: error)
                shouldShowErrorMessage = true
            }
        }
    }

    func turnOffSync() {
        Task { @MainActor in
            do {
                try await syncService.sync.disconnect()
            } catch {
                errorMessage = String(describing: error)
                shouldShowErrorMessage = true
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
        endFlow()
    }

    func endFlow() {
        currentDialog = nil
    }

    // MARK: -

    private func presentDialog(for currentDialog: SyncManagementDialogKind) {
        let shouldBeginSheet = self.currentDialog == nil
        self.currentDialog = currentDialog

        guard shouldBeginSheet else {
            return
        }

        let syncViewController = SyncManagementDialogViewController(self)
        let syncWindowController = syncViewController.wrappedInWindowController()

        guard let syncWindow = syncWindowController.window,
              let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController
        else {
            assertionFailure("Sync: Failed to present SyncSetupViewController")
            return
        }

        onEndFlow = {
            guard let window = syncWindowController.window, let sheetParent = window.sheetParent else {
                assertionFailure("window or sheet parent not present")
                return
            }
            sheetParent.endSheet(window)
        }

        parentWindowController.window?.beginSheet(syncWindow)
    }

    private var onEndFlow: () -> Void = {}

    private let syncService: SyncService
    private var isSyncEnabledCancellable: AnyCancellable?
}
