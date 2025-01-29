//
//  FaviconsFetcherOnboarding.swift
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

import Combine
import Foundation
import DDGSync
import SyncUI_macOS

final class FaviconsFetcherOnboarding {

    init(syncService: DDGSyncing, syncBookmarksAdapter: SyncBookmarksAdapter) {
        self.syncService = syncService
        self.syncBookmarksAdapter = syncBookmarksAdapter
        viewModel = FaviconsFetcherOnboardingViewModel()
        faviconsFetcherCancellable = viewModel.$isFaviconsFetchingEnabled.sink { [weak self] isEnabled in
            self?.shouldEnableFaviconsFetcherOnDismiss = isEnabled
        }
    }

    @MainActor
    func presentOnboardingIfNeeded(in targetWindow: NSWindow? = nil) {
        guard case .normal = NSApp.runType, shouldPresentOnboarding else {
            return
        }
        didPresentFaviconsFetchingOnboarding = true

        let viewController = FaviconsFetcherOnboardingViewController(viewModel)
        let windowController = viewController.wrappedInWindowController()

        guard let window = windowController.window,
              let parentWindow = targetWindow ?? WindowControllersManager.shared.lastKeyMainWindowController?.window
        else {
            assertionFailure("Failed to present FaviconsFetcherOnboardingViewController")
            return
        }

        viewModel.onDismiss = { [weak self] in
            guard let window = windowController.window, let sheetParent = window.sheetParent else {
                assertionFailure("window or sheet parent not present")
                return
            }
            sheetParent.endSheet(window)
            if self?.shouldEnableFaviconsFetcherOnDismiss == true {
                self?.syncBookmarksAdapter.isFaviconsFetchingEnabled = true
                self?.syncService.scheduler.notifyDataChanged()
            }
        }

        // Dispatching presentation asynchronously makes the UI less glitchy when presentation occurs during scrolling
        Task { @MainActor in
            parentWindow.beginSheet(window)
        }
    }

    private var shouldPresentOnboarding: Bool {
        syncService.featureFlags.contains(.userInterface)
        && !didPresentFaviconsFetchingOnboarding
        && !syncBookmarksAdapter.isFaviconsFetchingEnabled
        && syncBookmarksAdapter.isEligibleForFaviconsFetcherOnboarding
    }

    @UserDefaultsWrapper(key: .syncDidPresentFaviconsFetcherOnboarding, defaultValue: false)
    private var didPresentFaviconsFetchingOnboarding: Bool

    private let syncService: DDGSyncing
    private let syncBookmarksAdapter: SyncBookmarksAdapter
    private let viewModel: FaviconsFetcherOnboardingViewModel

    private var shouldEnableFaviconsFetcherOnDismiss: Bool = false
    private var faviconsFetcherCancellable: AnyCancellable?
}
