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
    var duckPlayerMode: DuckPlayerMode { get set }
    var youtubeOverlayInteracted: Bool { get set }
}

struct DuckPlayerPreferencesUserDefaultsPersistor: DuckPlayerPreferencesPersistor {
    var duckPlayerMode: DuckPlayerMode = .init(UserDefaultsWrapper(key: .duckPlayerMode, defaultValue: nil).wrappedValue) {
        didSet {
            var udWrapper = UserDefaultsWrapper(key: .duckPlayerMode, defaultValue: Bool?.none)
            udWrapper.wrappedValue = duckPlayerMode.boolValue
        }
    }

    @UserDefaultsWrapper(key: .youtubeOverlayInteracted, defaultValue: false)
    var youtubeOverlayInteracted: Bool
}

final class DuckPlayerPreferences: ObservableObject {

    static let shared = DuckPlayerPreferences()

    @Published
    var duckPlayerMode: DuckPlayerMode {
        didSet {
            persistor.duckPlayerMode = duckPlayerMode
        }
    }

    var youtubeOverlayInteracted: Bool {
        didSet {
            persistor.youtubeOverlayInteracted = youtubeOverlayInteracted
        }
    }

    init(persistor: DuckPlayerPreferencesPersistor = DuckPlayerPreferencesUserDefaultsPersistor()) {
        self.persistor = persistor
        duckPlayerMode = persistor.duckPlayerMode
        youtubeOverlayInteracted = persistor.youtubeOverlayInteracted
    }

    private var persistor: DuckPlayerPreferencesPersistor
    private var cancellables: Set<AnyCancellable> = []
}
