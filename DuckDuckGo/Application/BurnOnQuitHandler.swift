//
//  BurnOnQuitHandler.swift
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

import Foundation
import Combine

final class BurnOnQuitHandler {

    init(preferences: DataClearingPreferences, fireViewModel: FireViewModel) {
        self.preferences = preferences
        self.fireViewModel = fireViewModel
    }

    private let preferences: DataClearingPreferences
    private let fireViewModel: FireViewModel

    // MARK: - Burn On Quit

    var shouldBurnOnQuit: Bool {
        return preferences.isBurnDataOnQuitEnabled
    }

    private var shouldWarnOnBurn: Bool {
        return preferences.isWarnBeforeClearingEnabled
    }

    // Completion handler for all quit tasks
    var onBurnOnQuitCompleted: (() -> Void)?

    @MainActor
    func burnOnQuit() {
        guard shouldBurnOnQuit else { return }

        if shouldWarnOnBurn {
            let alert = NSAlert.burnOnQuitAlert()
            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else {
                appTerminationHandledCorrectly = true
                onBurnOnQuitCompleted?()
                return
            }
        }

        fireViewModel.fire.burnAll { [weak self] in
            self?.appTerminationHandledCorrectly = true
            self?.onBurnOnQuitCompleted?()
        }
    }

    // MARK: - Burn On Start
    // In case burning on quit wasn't successful (force quit, crash, etc.)

    @UserDefaultsWrapper(key: .appTerminationHandledCorrectly, defaultValue: false)
    private var appTerminationHandledCorrectly: Bool

    private var shouldBurnOnStart: Bool {
        return shouldBurnOnQuit && !appTerminationHandledCorrectly
    }

    func resetTheFlag() {
        appTerminationHandledCorrectly = false
    }

    @MainActor
    func burnOnStartIfNeeded() {
        guard preferences.isBurnDataOnQuitEnabled, shouldBurnOnStart else { return }

        fireViewModel.fire.burnAll()
    }

    // MARK: - Burn After

    private var inactivityTimer: Timer?

    var shouldBurnAfterDelay: Bool {
        preferences.isBurnDataOnQuitEnabled && preferences.clearDataAfter.timeInterval != nil
    }

    var burnTimeInterval: Double? {
        preferences.clearDataAfter.timeInterval
    }

    func applicationDidBecomeActive() {
        // Cancel the burn timer if the app becomes active
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }

    func applicationWillResignActive() {
        guard shouldBurnAfterDelay, let interval = burnTimeInterval else { return }

        inactivityTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.performBurnAfterDelay()
        }
    }

    private func performBurnAfterDelay() {
        DispatchQueue.main.async { [weak self] in
            self?.fireViewModel.fire.burnAll()
        }
    }

}
