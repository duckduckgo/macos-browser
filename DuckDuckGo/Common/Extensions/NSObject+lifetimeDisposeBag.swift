//
//  NSObject+lifetimeDisposeBag.swift
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
import Combine

final private class AnyCancellableStorage: NSObject {
    var set = Set<AnyCancellable>()
}

extension NSObject {

    private static let lifetimeDisposeBagKey = UnsafeRawPointer(bitPattern: "lifetimeDisposeBagKey".hashValue)!

    var lifetimeDisposeBag: Set<AnyCancellable> {
        get {
            guard let storage = objc_getAssociatedObject(self, Self.lifetimeDisposeBagKey) as? AnyCancellableStorage
            else {
                return []
            }
            return storage.set
        }
        set {
            var storage = objc_getAssociatedObject(self, Self.lifetimeDisposeBagKey) as? AnyCancellableStorage
            if storage == nil {
                storage = AnyCancellableStorage()
                objc_setAssociatedObject(self, Self.lifetimeDisposeBagKey, storage!, .OBJC_ASSOCIATION_RETAIN)
            }
            storage!.set = newValue
        }
    }

}
