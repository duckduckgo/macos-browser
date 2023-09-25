//
//  DataBrokerDebugFlag.swift
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

public enum DataBrokerDebugFlagType: String {
    case fakeBroker
    case blockScheduler
}

public protocol DataBrokerDebugFlag {
    var flagKey: String { get }

    func isFlagOn() -> Bool
    func setFlag(_ flag: Bool)
}

extension DataBrokerDebugFlag where DataBrokerDebugFlagType.RawValue == String {
    public func isFlagOn() -> Bool {
        return UserDefaults.standard.bool(forKey: flagKey)
    }

    public func setFlag(_ flag: Bool) {
        UserDefaults.standard.set(flag, forKey: flagKey)
    }
}

public struct DataBrokerDebugFlagBlockScheduler: DataBrokerDebugFlag {
    public let flagKey = "dbp:blockScheduler"

    public init() { }
}

public struct DataBrokerDebugFlagFakeBroker: DataBrokerDebugFlag {
    public let flagKey = "dbp:useFakeBrokerKey"

    public init() { }
}

public struct DataBrokerDebugFlagShowWebView: DataBrokerDebugFlag {
    public let flagKey = "dbp:showWebViews"

    public init() { }
}
