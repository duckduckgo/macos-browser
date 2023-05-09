//
//  NetworkProtectionTimer.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

/// Wraps `DispatchSourceTimer` to reduce the boilerplate code for the rest of the code.
///
final class NetworkProtectionTimer {
    private let queue: DispatchQueue
    private let handler: (NetworkProtectionTimer) -> Void
    private var timer: DispatchSourceTimer?

    init(queue: DispatchQueue, handler: @escaping (NetworkProtectionTimer) -> Void) {
        self.queue = queue
        self.handler = handler
    }

    deinit {
        cancel()
    }

    func schedule(wallDeadline: DispatchWallTime) {
        cancel()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(wallDeadline: wallDeadline)
        timer.setEventHandler { [weak self] in
            guard let self = self else {
                return
            }

            self.handler(self)
        }
        timer.resume()

        self.timer = timer
    }

    var isScheduled: Bool {
        guard let timer = self.timer else {
            return false
        }

        return !timer.isCancelled
    }

    /// If the handler immediately, regardless of whether it was scheduled.
    ///
    /// If the timer was scheduled to run, this method will cancel it.
    ///
    func fire() {
        cancel()
        handler(self)
    }

    func cancel() {
        if let timer = timer {
            if !timer.isCancelled {
                timer.cancel()
            }

            self.timer = nil
        }
    }
}
