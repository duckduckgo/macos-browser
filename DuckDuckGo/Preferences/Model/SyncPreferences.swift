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

final class SyncPreferences: ObservableObject {

    @Published private(set) var isSyncEnabled: Bool = false

    @Published var syncKey: String

    @Published var shouldShowErrorMessage: Bool = false
    @Published var errorMessage: String?

    init(syncService: SyncService = .shared) {
        self.syncService = syncService
        self.isSyncEnabled = syncService.sync.isAuthenticated
        self.syncKey = syncService.sync.recoveryCode.flatMap { String(bytes: $0, encoding: .utf8) } ?? ""

        isSyncEnabledCancellable = syncService.sync.isAuthenticatedPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.isSyncEnabled, onWeaklyHeld: self)
    }

    func presentEnableSyncDialog() {
        let enableSyncWindowController = SyncSetupViewController.create(with: syncService).wrappedInWindowController()

        guard let enableSyncWindow = enableSyncWindowController.window,
              let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController
        else {
            assertionFailure("Sync: Failed to present EnableSyncViewController")
            return
        }

        parentWindowController.window?.beginSheet(enableSyncWindow)
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

    private let syncService: SyncService
    private var isSyncEnabledCancellable: AnyCancellable?
}

struct SyncedDevice: Identifiable {

    enum Kind: Equatable {
        case current, desktop, mobile
    }

    let kind: Kind
    let name: String
    let id: String

    var isCurrent: Bool {
        kind == .current
    }
}
