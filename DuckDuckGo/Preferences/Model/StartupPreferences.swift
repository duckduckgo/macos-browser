//
//  StartupPreferences.swift
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

protocol StartupPreferencesPersistor {
    var restorePreviousSession: Bool { get set }
}

struct StartupPreferencesUserDefaultsPersistor: StartupPreferencesPersistor {
    @UserDefaultsWrapper(key: .restorePreviousSession, defaultValue: false)
    var restorePreviousSession: Bool
}

final class StartupPreferences: ObservableObject {

    @Published var restorePreviousSession: Bool {
        didSet {
            persistor.restorePreviousSession = restorePreviousSession
        }
    }

    init(persistor: StartupPreferencesPersistor = StartupPreferencesUserDefaultsPersistor()) {
        self.persistor = persistor
        restorePreviousSession = persistor.restorePreviousSession
    }

    private var persistor: StartupPreferencesPersistor
}
