//
//  PublishedAfter.swift
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

import Combine

@propertyWrapper
struct PublishedAfter<Value> {

    private let subject: CurrentValueSubject<Value, Never>

    init(initialValue: Value) {
        self.init(wrappedValue: initialValue)
    }

    init(wrappedValue: Value) {
        subject = CurrentValueSubject(wrappedValue)
    }

    var projectedValue: CurrentValueSubject<Value, Never> {
        return subject
    }

    @available(*, unavailable, message: "@PublishedAfter is only available on properties of classes")
    var wrappedValue: Value {
        get { fatalError() }
        // swiftlint:disable unused_setter_value
        set { fatalError() }
        // swiftlint:enable unused_setter_value
    }

    static subscript<EnclosingSelf: AnyObject>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, PublishedAfter<Value>>
    ) -> Value {
        get {
            object[keyPath: storageKeyPath].subject.value
        }
        set {
            object[keyPath: storageKeyPath].subject.send(newValue)
        }
    }

}
