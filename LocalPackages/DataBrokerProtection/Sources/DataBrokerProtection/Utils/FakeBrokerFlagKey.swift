//
//  FakeBrokerFlag.swift
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

public struct FakeBrokerFlagKey {
    public static let useFakeBrokerKey = "useFakeBrokerKey"
}

public protocol FakeBrokerFlag {
    func isFakeBrokerFlagOn() -> Bool
    func setFakeBrokerFlag(_ status: Bool)
}

public class FakeBrokerUserDefaults: FakeBrokerFlag {

    public init() { }

    public func isFakeBrokerFlagOn() -> Bool {
        return UserDefaults.standard.bool(forKey: FakeBrokerFlagKey.useFakeBrokerKey)
    }

    public func setFakeBrokerFlag(_ status: Bool) {
        UserDefaults.standard.set(status, forKey: FakeBrokerFlagKey.useFakeBrokerKey)
    }
}
