//
//  DefaultHeaderKeyStore.swift
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

import Foundation

protocol DefaultHeaderKeyStore: AnyObject {

    var debugHeaderKey: String? { get set }
    func reset()
}

public final class DefaultHeaderKeyUserDefaultsStore: DefaultHeaderKeyStore {

    private enum Constants {
        static let debugHeaderKey = "network-protection.debug-header-key"
    }

    public var debugHeaderKey: String? {
        get {
            userDefaults.string(forKey: Constants.debugHeaderKey)
        }

        set {
            guard let newValue else {
                reset()
                return
            }

            userDefaults.set(newValue, forKey: Constants.debugHeaderKey)
        }
    }

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func reset() {
        userDefaults.removeObject(forKey: Constants.debugHeaderKey)
    }

}
