//
//  DuckPlayerPreferences.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

protocol DuckPlayerPreferencesPersistor {
    /// The persistor hadles raw Bool values but each one translates into a DuckPlayerMode:
    /// nil = .alwaysAsk,  false = .disabled, true = .enabled
    /// DuckPlayerMode init takes a Bool and returns the corresponding mode
    var duckPlayerModeBool: Bool? { get set }
    var youtubeOverlayInteracted: Bool { get set }
    var youtubeOverlayAnyButtonPressed: Bool { get set }
}

struct DuckPlayerPreferencesUserDefaultsPersistor: DuckPlayerPreferencesPersistor {

    @UserDefaultsWrapper(key: .duckPlayerMode, defaultValue: nil)
    var duckPlayerModeBool: Bool?

    @UserDefaultsWrapper(key: .youtubeOverlayInteracted, defaultValue: false)
    var youtubeOverlayInteracted: Bool

    @UserDefaultsWrapper(key: .youtubeOverlayButtonsUsed, defaultValue: false)
    var youtubeOverlayAnyButtonPressed: Bool
}

final class DuckPlayerPreferences: ObservableObject {

    static let shared = DuckPlayerPreferences()

    @Published
    var duckPlayerMode: DuckPlayerMode {
        didSet {
            persistor.duckPlayerModeBool = duckPlayerMode.boolValue
        }
    }

    var youtubeOverlayInteracted: Bool {
        didSet {
            persistor.youtubeOverlayInteracted = youtubeOverlayInteracted
        }
    }

    var youtubeOverlayAnyButtonPressed: Bool {
        didSet {
            persistor.youtubeOverlayAnyButtonPressed = youtubeOverlayAnyButtonPressed
        }
    }

    init(persistor: DuckPlayerPreferencesPersistor = DuckPlayerPreferencesUserDefaultsPersistor()) {
        self.persistor = persistor
        duckPlayerMode = .init(persistor.duckPlayerModeBool)
        youtubeOverlayInteracted = persistor.youtubeOverlayInteracted
        youtubeOverlayAnyButtonPressed = persistor.youtubeOverlayAnyButtonPressed
    }

    private var persistor: DuckPlayerPreferencesPersistor
    private var cancellables: Set<AnyCancellable> = []
}
