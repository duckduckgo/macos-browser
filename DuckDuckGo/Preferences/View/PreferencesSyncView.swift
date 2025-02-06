//
//  PreferencesSyncView.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import SwiftUI
import Common
import SyncUI_macOS
import SwiftUIExtensions
import BrowserServicesKit
import os.log

struct SyncView: View {

    var body: some View {
        if let syncService = NSApp.delegateTyped.syncService, let syncDataProviders = NSApp.delegateTyped.syncDataProviders {
            let syncPreferences = SyncPreferences(
                syncService: syncService,
                syncBookmarksAdapter: syncDataProviders.bookmarksAdapter,
                syncCredentialsAdapter: syncDataProviders.credentialsAdapter,
                syncPausedStateManager: syncDataProviders.syncErrorHandler
            )
            SyncUI_macOS.ManagementView(model: syncPreferences)
                .onAppear {
                    requestSync()
                }
        } else {
            FailedAssertionView("Failed to initialize Sync Management View")
        }
    }

    private func requestSync() {
        Task { @MainActor in
            guard let syncService = (NSApp.delegate as? AppDelegate)?.syncService else {
                return
            }
            Logger.sync.debug("Requesting sync if enabled")
            syncService.scheduler.notifyDataChanged()
        }
    }
}
