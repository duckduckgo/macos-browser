//
//  SyncSetupViewModel.swift
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

import SwiftUI
import Combine

final class SyncSetupViewModel: ObservableObject {
    enum FlowState {
        case enableSync, syncAnotherDevice, syncNewDevice, deviceSynced, saveRecoveryPDF
    }

    @Published var flowState: FlowState = .enableSync
    @Published var shouldDisableSubmitButton: Bool

    let preferences: SyncPreferences
    let onCancel: () -> Void

    init(preferences: SyncPreferences, onCancel: @escaping () -> Void) {
        self.preferences = preferences
        self.onCancel = onCancel
        self.shouldDisableSubmitButton = true

        shouldDisableSubmitButtonCancellable = preferences.$remoteSyncKey
            .map { key in
                guard let key else {
                    return true
                }
                return key.isEmpty
            }
            .assign(to: \.shouldDisableSubmitButton, onWeaklyHeld: self)
    }

    private var shouldDisableSubmitButtonCancellable: AnyCancellable?
}
