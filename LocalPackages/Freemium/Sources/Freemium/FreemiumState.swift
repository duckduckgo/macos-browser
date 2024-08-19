//
//  FreemiumState.swift
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

/// `UserDefault` keys
private enum Keys {
    static let pir = "macos.browser.freemium.pir"
}

protocol FreemiumState {
    var hasFreemiumPIR: Bool { get set }
}

public final class DefaultFreemiumState: FreemiumState {

    private let userDefaults: UserDefaults

    public var hasFreemiumPIR: Bool {
        get {
            userDefaults.bool(forKey: Keys.pir)
        } set {
            userDefaults.set(newValue, forKey: Keys.pir)
        }
    }

    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
}
