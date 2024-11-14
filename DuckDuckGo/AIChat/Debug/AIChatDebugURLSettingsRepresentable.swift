//
//  AIChatDebugURLSettingsRepresentable.swift
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

public protocol AIChatDebugURLSettingsRepresentable {
    var customURLHostname: String? { get }
    var customURL: String? { get set }
    func reset()
}

public final class AIChatDebugURLSettings: AIChatDebugURLSettingsRepresentable {
    private let userDefault: UserDefaults

    public init(_ userDefault: UserDefaults = .standard) {
        self.userDefault = userDefault
    }

    public var customURLHostname: String? {
        if let customURL = customURL,
            let url = URL(string: customURL) {
            return url.host
        }
        return nil
    }

    public var customURL: String? {
        get {
            userDefault[.customURL]
        } set {
            userDefault[.customURL] = newValue
        }
    }

    public func reset() {
        customURL = nil
    }
}

private extension UserDefaults {
    enum Key: String {
        case customURL
    }

    subscript<T>(key: Key) -> T? where T: Any {
        get {
            return value(forKey: key.rawValue) as? T
        }
        set {
            set(newValue, forKey: key.rawValue)
        }
    }

}
