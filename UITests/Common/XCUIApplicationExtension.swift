//
//  XCUIApplicationExtension.swift
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

import Common
import Foundation
import XCTest

extension XCUIApplication {

    // Target Application \'com.duckduckgo.macos.browser.debug\'
    private static let bundleIdRegex = try! NSRegularExpression(pattern: "Target Application \\'(.+)\\'", options: [])
    var bundleId: String {
        let description = self.description
        let bundleIdRange = Self.bundleIdRegex.firstMatch(in: description, options: [], range: description.fullRange)!.range(at: 1)
        return String(description[bundleIdRange]!)
    }

    var uiTestsEnvironment: [UITestEnvironmentKey: UITestEnvironmentValue] {
        get {
            self.launchEnvironment.reduce(into: [:]) { (result, item) in
                if let key = UITestEnvironmentKey(rawValue: item.key),
                   let value = UITestEnvironmentValue(rawValue: item.value) {
                    result[key] = value
                }
            }
        }
        _modify {
            var value = self.uiTestsEnvironment
            let oldValue = value
            yield &value
            for change in value.map(EnvironmentKeyValuePair.init).difference(from: oldValue.map(EnvironmentKeyValuePair.init)) {
                switch change {
                case .insert(offset: _, element: let element, associatedWith: _):
                    self.launchEnvironment[element.key.rawValue] = element.value.rawValue
                case .remove(offset: _, element: let element, associatedWith: _):
                    self.launchEnvironment[element.key.rawValue] = nil
                }
            }
        }
    }

}

private struct EnvironmentKeyValuePair: Equatable {
    let key: UITestEnvironmentKey
    let value: UITestEnvironmentValue

}
