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

struct SyncDevice: Identifiable {

    enum Kind: Equatable {
        case current, desktop, mobile
    }

    let kind: Kind
    let name: String
    let id: String

    var isCurrent: Bool {
        kind == .current
    }

    init(_ account: SyncAccount) {
        self.name = account.deviceName
        self.id = account.deviceId
        self.kind = .current
    }

    init(_ device: RegisteredDevice) {
        self.name = device.name
        self.id = device.id
        self.kind = .mobile
    }
}

final class SyncPreferences: ObservableObject {
    enum FlowState {
        case enableSync, recoverAccount, syncAnotherDevice, syncNewDevice, deviceSynced, saveRecoveryPDF
    }

    var isSyncEnabled: Bool {
        account != nil
    }

    @Published var flowState: FlowState? {
        didSet {
            if flowState == nil && oldValue != nil {
                onEndFlow()
            }
        }
    }

    @Published var account: SyncAccount?
    @Published var devices: [SyncDevice] = []

    @Published var shouldShowErrorMessage: Bool = false
    @Published var errorMessage: String?


    init(syncService: SyncService = .shared) {
        self.syncService = syncService
        updateValues()

        isSyncEnabledCancellable = syncService.sync.isAuthenticatedPublisher
            .removeDuplicates()
            .asVoid()
            .receive(on: DispatchQueue.main)
            .sink { [weak self]  in
                self?.updateValues()
            }
    }

    private func updateValues() {
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
        flowState = .enableSync
        presentDialog()
    }

    func presentRecoverSyncAccountDialog() {
        flowState = .recoverAccount
        presentDialog()
    }

    func turnOnSync() {
        Task { @MainActor in
            do {
                try await syncService.sync.createAccount(deviceName: ProcessInfo.processInfo.hostName)
                flowState = .syncAnotherDevice
            } catch {
                errorMessage = String(describing: error)
                shouldShowErrorMessage = true
            }
        }
    }

    func recoverDevice(using recoveryCode: String) {
        Task { @MainActor in
            do {
                try await syncService.sync.login(recoveryKey: recoveryCode, deviceName: ProcessInfo.processInfo.hostName)
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

    func endFlow() {
        flowState = nil
    }

    // MARK: -

    private func presentDialog() {
        let syncViewController = SyncSetupViewController(self)
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
