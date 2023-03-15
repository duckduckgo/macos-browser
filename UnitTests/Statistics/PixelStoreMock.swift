//
//  PixelStoreMock.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
@testable import DuckDuckGo_Privacy_Browser

final class PixelStoreMock: PixelDataStore {

    var data = [String: Any]()

    func value(forKey key: String) -> Int? {
        return (data[key] as? NSNumber)?.intValue
    }

    func set(_ value: Int, forKey key: String, completionHandler: ((Error?) -> Void)?) {
        data[key] = NSNumber(value: value)
        completionHandler?(nil)
    }

    func value(forKey key: String) -> Double? {
        return (data[key] as? NSNumber)?.doubleValue
    }

    func set(_ value: Double, forKey key: String, completionHandler: ((Error?) -> Void)?) {
        data[key] = NSNumber(value: value)
        completionHandler?(nil)
    }

    func value(forKey key: String) -> String? {
        return data[key] as? String
    }

    func set(_ value: String, forKey key: String, completionHandler: ((Error?) -> Void)?) {
        data[key] = value
        completionHandler?(nil)
    }

    func removeValue(forKey key: String, completionHandler: ((Error?) -> Void)?) {
        data[key] = nil
        completionHandler?(nil)
    }

}
