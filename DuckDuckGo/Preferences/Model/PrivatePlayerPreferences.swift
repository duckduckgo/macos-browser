//
//  PrivatePlayerPreferences.swift
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

protocol PrivatePlayerPreferencesPersistor {
    var privatePlayerMode: PrivatePlayerMode { get set }
}

struct PrivatePlayerPreferencesUserDefaultsPersistor: PrivatePlayerPreferencesPersistor {
    var privatePlayerMode: PrivatePlayerMode = .init(UserDefaultsWrapper(key: .privatePlayerMode, defaultValue: nil).wrappedValue) {
        didSet {
            var udWrapper = UserDefaultsWrapper(key: .privatePlayerMode, defaultValue: Bool?.none)
            udWrapper.wrappedValue = privatePlayerMode.boolValue
        }
    }
}

final class PrivatePlayerPreferences: ObservableObject {

    static let shared = PrivatePlayerPreferences()

    @Published
    var privatePlayerMode: PrivatePlayerMode {
        didSet {
            persistor.privatePlayerMode = privatePlayerMode
        }
    }

    init(persistor: PrivatePlayerPreferencesPersistor = PrivatePlayerPreferencesUserDefaultsPersistor()) {
        self.persistor = persistor
        privatePlayerMode = persistor.privatePlayerMode
    }

    private var persistor: PrivatePlayerPreferencesPersistor
    private var cancellables: Set<AnyCancellable> = []
}
