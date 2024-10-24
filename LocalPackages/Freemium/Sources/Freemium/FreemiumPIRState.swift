//
//  FreemiumPIRState.swift
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

/// `FreemiumPIRState` types provide access to Freemium PIR-related state
protocol FreemiumPIRState {
    var didOnboard: Bool { get set }
}

/// Default implementation of `FreemiumPIRState`. `UserDefaults` is used as underlying storage.
public final class DefaultFreemiumPIRState: FreemiumPIRState {

    private let userDefaults: UserDefaults
    private let key = "macos.browser.freemium.pir"

    public var didOnboard: Bool {
        get {
            userDefaults.bool(forKey: key)
        } set {
            userDefaults.set(newValue, forKey: key)
        }
    }

    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }
}
