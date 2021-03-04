//
//  NSEvent+Publisher.swift
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

import Cocoa
import Combine

extension NSEvent {

    static func localEvents(for mask: EventTypeMask) -> LocalEvents {
        return LocalEvents(for: mask)
    }

    static func globalEvents(for mask: EventTypeMask) -> GlobalEvents {
        return GlobalEvents(for: mask)
    }

    struct LocalEvents: Publisher {
        typealias Output = (event: NSEvent, handled: () -> Void)
        typealias Failure = Never

        let mask: EventTypeMask

        init(for mask: EventTypeMask) {
            self.mask = mask
        }

        func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure {

            let monitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event -> NSEvent? in
                var returnValue: NSEvent? = event
                _=subscriber.receive(Output(event: event, handled: {
                    returnValue = nil
                }))
                return returnValue
            }

            let subscription = NSEventSubscription(monitor: monitor)
            subscriber.receive(subscription: subscription)
        }
    }

    struct GlobalEvents: Publisher {
        typealias Output = NSEvent
        typealias Failure = Never

        let mask: EventTypeMask

        init(for mask: EventTypeMask) {
            self.mask = mask
        }

        func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure {

            let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { _=subscriber.receive($0) }

            let subscription = NSEventSubscription(monitor: monitor)
            subscriber.receive(subscription: subscription)
        }
    }

}

final class NSEventSubscription: Subscription {

    private var monitor: Any?

    init(monitor: Any?) {
        self.monitor = monitor
    }

    func request(_ demand: Subscribers.Demand) {
        // only notifying on event
    }

    func cancel() {
        dispatchPrecondition(condition: .onQueue(.main))

        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        self.monitor = nil
    }

    deinit {
        dispatchPrecondition(condition: .onQueue(.main))

        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

}
