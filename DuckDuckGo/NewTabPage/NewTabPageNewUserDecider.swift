//
//  NewTabPageNewUserDecider.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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
import Persistence

protocol NewTabPageNewUserDeciding {
    var isNewUser: Bool { get set }
}

final class NewTabPageNewUserDecider: NewTabPageNewUserDeciding {

    enum Keys {
        static let isNewUser = "new-tab-page.is-new-user"
    }

    var isNewUser: Bool {
        get {
            return keyValueStore.object(forKey: Keys.isNewUser) as? Bool ?? false
        }
        set { keyValueStore.set(newValue, forKey: Keys.isNewUser) }
    }

    let keyValueStore: KeyValueStoring

    init(keyValueStore: KeyValueStoring = UserDefaults.standard) {
        self.keyValueStore = keyValueStore
        initializeStorageIfNeeded()
    }

    private func initializeStorageIfNeeded() {
#if DEBUG
        isNewUser = false
#else
        guard keyValueStore.object(forKey: Keys.isNewUser) == nil else {
            return
        }
        isNewUser = UserDefaultsWrapper<Bool>(key: .onboardingFinished, defaultValue: false).wrappedValue
#endif
    }
}
