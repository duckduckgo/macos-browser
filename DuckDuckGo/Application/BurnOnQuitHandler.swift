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

    init(preferences: DataClearingPreferences,
         fireCoordinator: FireCoordinator ) {
        self.preferences = preferences
        self.fireCoordinator = fireCoordinator
    }

    private let preferences: DataClearingPreferences
    private let fireCoordinator: FireCoordinator

    // MARK: - Burn On Quit

    var shouldBurnOnQuit: Bool {
        return preferences.isBurnDataOnQuitEnabled
    }

    // Completion handler for all quit tasks
    var onBurnOnQuitCompleted: (() -> Void)?

    @MainActor
    func burnOnQuit() {
        guard shouldBurnOnQuit else { return }
        // TODO: Refactor from static
        FireCoordinator.fireViewModel.fire.burnAll { [weak self] in
            self?.burnPerformedSuccessfullyOnQuit = true
            self?.onBurnOnQuitCompleted?()
        }
    }

    // MARK: - Burn On Start
    // In case the burn on quit wasn't successfull

    @UserDefaultsWrapper(key: .burnPerformedSuccessfullyOnQuit, defaultValue: false)
    private var burnPerformedSuccessfullyOnQuit: Bool

    var shouldBurnOnStart: Bool {
        return !burnPerformedSuccessfullyOnQuit
    }

    func resetTheFlag() {
        burnPerformedSuccessfullyOnQuit = false
    }

    @MainActor
    func burnOnStartIfNeeded() {
        guard preferences.isBurnDataOnQuitEnabled, shouldBurnOnStart else { return }

        FireCoordinator.fireViewModel.fire.burnAll()
    }

}
