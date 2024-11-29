//
//  CurrentValuePublisher.swift
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
import Foundation

public final class CurrentValuePublisher<Output, Failure: Error> {

    private(set) public var value: Output
    private let wrappedPublisher: AnyPublisher<Output, Failure>
    private var cancellable: AnyCancellable?

    public init(initialValue: Output, publisher: AnyPublisher<Output, Failure>) {
        value = initialValue
        wrappedPublisher = publisher

        subscribeToPublisherUpdates()
    }

    private func subscribeToPublisherUpdates() {
        cancellable = wrappedPublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }) { [weak self] value in
                self?.value = value
            }
    }
}

extension CurrentValuePublisher: Publisher {
    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        wrappedPublisher.receive(subscriber: subscriber)
    }
}
