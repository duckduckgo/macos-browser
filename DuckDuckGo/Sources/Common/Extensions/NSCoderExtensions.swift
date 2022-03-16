//
//  NSCoderExtensions.swift
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

extension NSCoder {

    func encode<T: NSObject>(forKey key: String) -> (T) -> Void where T: NSSecureCoding {
        return { object in
            self.encode(object, forKey: key)
        }
    }

    func encode<T: _ObjectiveCBridgeable>(forKey key: String) -> (T) -> Void
        where T._ObjectiveCType: NSObject, T._ObjectiveCType: NSSecureCoding {

        return { object in
            self.encode(object._bridgeToObjectiveC(), forKey: key)
        }
    }

    func encode(forKey key: String) -> (Int) -> Void {
        return { integer in
            self.encode(integer, forKey: key)
        }
    }

    func decodeIfPresent(at key: String) -> Int? {
        guard containsValue(forKey: key) else { return nil }
        return decodeInteger(forKey: key)
    }

    func decodeIfPresent<T: NSObject>(at key: String) -> T? where T: NSSecureCoding {
        guard containsValue(forKey: key) else { return nil }
        return decodeObject(of: T.self, forKey: key)
    }

    func decodeIfPresent<T: _ObjectiveCBridgeable>(at key: String) -> T?
        where T._ObjectiveCType: NSObject, T._ObjectiveCType: NSSecureCoding {

        guard containsValue(forKey: key),
            let obj = decodeObject(of: T._ObjectiveCType.self, forKey: key)
        else {
            return nil
        }
        return T._unconditionallyBridgeFromObjectiveC(obj)
    }

}
