//
//  Publishers.NestedObjectChanges.swift
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

extension Publisher where Output: Sequence, Output.Element: Hashable, Failure == Never {

    func nestedObjectChanges<P: Publisher>(_ transform: @escaping (Output.Element) -> P) -> Publishers.NestedObjectChanges<P, Self> {
        Publishers.NestedObjectChanges(upstream: self, transform: transform)
    }

    func nestedObjectChanges<P: Publisher>(_ keyPath: KeyPath<Output.Element, P>) -> Publishers.NestedObjectChanges<P, Self> {
        Publishers.NestedObjectChanges(upstream: self) { $0[keyPath: keyPath] }
    }

}

extension Publishers {

    struct NestedObjectChanges<NestedPublisher: Publisher, Upstream: Publisher>: Publisher
    where Upstream.Output: Swift.Sequence,
          Upstream.Output.Element: Hashable,
          Upstream.Failure == Never,
          NestedPublisher.Failure == Never {

        typealias Output = Void
        typealias Failure = Never

        private let upstream: Upstream
        private let transform: (Upstream.Output.Element) -> NestedPublisher

        init(upstream: Upstream, transform: @escaping (Upstream.Output.Element) -> NestedPublisher) {
            self.upstream = upstream
            self.transform = transform
        }

        func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure {

            let inner = Inner(parent: self, subscriber: subscriber)
            subscriber.receive(subscription: inner)
        }
    }

}

extension Publishers.NestedObjectChanges {

    private final class Inner<S: Subscriber>: Subscription where S.Input == Void, S.Failure == Never {

        typealias Parent = Publishers.NestedObjectChanges<NestedPublisher, Upstream>
        typealias Element = Upstream.Output.Element

        private let parent: Parent
        private let subscriber: S

        private var cancellable: AnyCancellable?
        private var current = Set<Element>()
        private var nested = [Element: AnyCancellable]()

        init(parent: Parent, subscriber: S) {
            self.parent = parent
            self.subscriber = subscriber

            self.cancellable = parent.upstream.sink { [weak self] value in
                self?.valueChanged(value)
            }
        }

        func request(_ demand: Subscribers.Demand) {
            // only notifying on change, not by-request
        }

        func cancel() {
            dispatchPrecondition(condition: .onQueue(.main))

            cancellable = nil
            nested = [:]
            current = []
        }

        private func valueChanged(_ newValue: Upstream.Output) {
            dispatchPrecondition(condition: .onQueue(.main))

            let set = Set(newValue)
            let added = set.subtracting(self.current)
            let removed = self.current.subtracting(set)
            self.current = set

            subscribe(to: added)
            removeSubscriptions(for: removed)

            // skip initial sink
            if case .some = self.cancellable {
                _=subscriber.receive( () )
            }
        }

        private func subscribe(to added: Set<Element>) {
            for item in added {
                self.nested[item] = parent.transform(item).sink { [weak self] _ in
                    dispatchPrecondition(condition: .onQueue(.main))
                    // skip initial sink
                    guard case .some = self?.nested[item] else { return }

                    _=self?.subscriber.receive( () )
                }
            }
        }

        private func removeSubscriptions(for removed: Set<Element>) {
            for item in removed {
                self.nested[item] = nil
            }
        }

    }
}
