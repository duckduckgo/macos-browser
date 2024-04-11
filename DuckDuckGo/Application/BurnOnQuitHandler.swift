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

    private let preferences: DataClearingPreferences
    private let fireViewModel: FireViewModel

    init(preferences: DataClearingPreferences, fireViewModel: FireViewModel) {
        self.preferences = preferences
        self.fireViewModel = fireViewModel
    }

    var onBurnOnQuitCompleted: (() -> Void)?

    @MainActor
    func handleAppTermination() -> NSApplication.TerminateReply? {
        guard preferences.isBurnDataOnQuitEnabled else { return nil }

        if preferences.isWarnBeforeClearingEnabled, !confirmBurnOnQuit() {
            return .terminateCancel
        }

        performBurnOnQuit()
        return .terminateLater
    }

    func resetTheFlag() {
        appTerminationHandledCorrectly = false
    }

    // MARK: - Private

    private func confirmBurnOnQuit() -> Bool {
        let alert = NSAlert.burnOnQuitAlert()
        let response = alert.runModal()
        return response == .alertFirstButtonReturn
    }

    @MainActor
    private func performBurnOnQuit() {
        fireViewModel.fire.burnAll { [weak self] in
            self?.appTerminationHandledCorrectly = true
            self?.onBurnOnQuitCompleted?()
        }
    }

    // MARK: - Burn On Start
    // Burning on quit wasn't successful

    @UserDefaultsWrapper(key: .appTerminationHandledCorrectly, defaultValue: false)
    private var appTerminationHandledCorrectly: Bool

    @MainActor
    func burnOnStartIfNeeded() {
        let shouldBurnOnStart = preferences.isBurnDataOnQuitEnabled && !appTerminationHandledCorrectly
        guard shouldBurnOnStart else { return }

        fireViewModel.fire.burnAll()
    }
}
