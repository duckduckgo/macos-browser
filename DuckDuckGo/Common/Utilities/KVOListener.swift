//
//  KVOListener.swift
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

import Combine

final class KVOListener<ObjectType: NSObject, ValueType>: Publisher {

    typealias Output = ValueType
    typealias Failure = Never

    private var object: ObjectType
    private var keyPath: String

    init(object: ObjectType, keyPath: String) {
        self.object = object
        self.keyPath = keyPath
    }

    func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, ValueType == S.Input {
        let subscription = KVOSubscription(subscriber: subscriber, object: object, keyPath: keyPath)
        subscriber.receive(subscription: subscription)
    }

    private final class KVOSubscription<S: Subscriber, ObjectType: NSObject, ValueType>: NSObject, Subscription where S.Input == ValueType {

        private var subscriber: S?
        private var object: ObjectType
        private var keyPath: String

        init(subscriber: S, object: ObjectType, keyPath: String) {
            self.subscriber = subscriber
            self.object = object
            self.keyPath = keyPath
            super.init()
            self.object.addObserver(self, forKeyPath: keyPath, options: [.new], context: nil)
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == self.keyPath, let newValue = change?[.newKey] as? ValueType {
                _ = subscriber?.receive(newValue)
            }
        }

        func request(_ demand: Subscribers.Demand) {
            // We don't need to handle backpressure for this.
        }

        func cancel() {
            subscriber = nil
            object.removeObserver(self, forKeyPath: keyPath)
        }
    }
}
