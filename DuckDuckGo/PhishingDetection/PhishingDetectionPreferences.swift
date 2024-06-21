//
//  PhishingDetectionPreferences.swift
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

protocol PhishingDetectionPreferencesPersistor {
    var isEnabled: Bool { get set }
}

struct PhishingDetectionPreferencesUserDefaultsPersistor: PhishingDetectionPreferencesPersistor {

    @UserDefaultsWrapper(key: .phishingDetectionEnabled, defaultValue: true)
    var isEnabled: Bool
}

final class PhishingDetectionPreferences: ObservableObject {

    static let shared = PhishingDetectionPreferences()

    @Published
    var isEnabled: Bool {
        didSet {
            persistor.isEnabled = isEnabled
        }
    }

    init(persistor: PhishingDetectionPreferencesPersistor = PhishingDetectionPreferencesUserDefaultsPersistor()) {
        self.persistor = persistor
        self.isEnabled = persistor.isEnabled
    }

    private var persistor: PhishingDetectionPreferencesPersistor
    private var cancellables: Set<AnyCancellable> = []
}
