//
//  Image+NetworkProtection.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

/// Exactly like Combine's `CurrentValueSubject` but without allowing external actors to modify the current value.
///
/// This type of publisher offers a mechanism for immediately returning the current known value without having to wait
/// for publisher callbacks.
///
public final class CurrentValuePublisher<Output, Failure>: Publisher where Failure: Error {

    public private(set) var value: Output
    private let underlyingPublisher: AnyPublisher<Output, Failure>

    public init(initialValue: Output, underlyingPublisher: AnyPublisher<Output, Failure>) {
        value = initialValue
        self.underlyingPublisher = underlyingPublisher
    }

    // MARK: - Publisher

    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        underlyingPublisher.receive(subscriber: subscriber)
    }
}
