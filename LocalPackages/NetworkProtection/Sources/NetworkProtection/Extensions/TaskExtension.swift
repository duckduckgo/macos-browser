//
//  TaskExtension.swift
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

public extension Task where Success == Never, Failure == Error {

    static func periodic(priority: TaskPriority? = nil,
                         delay: TimeInterval? = nil,
                         interval: TimeInterval,
                         operation: @escaping @Sendable () async -> Void,
                         cancellationHandler: (@Sendable () async -> Void)? = nil) -> Task {

        Task.detached(priority: priority) {
            do {
                if let delay {
                    try await Task<Never, Never>.sleep(interval: delay)
                }

                repeat {
                    await operation()

                    try await Task<Never, Never>.sleep(interval: interval)
                } while true
            } catch {
                await cancellationHandler?()
                throw error
            }
        }

    }

}

public extension Task where Success == Never, Failure == Never {

    static func sleep(interval: TimeInterval) async throws {
        assert(interval > 0)
        try await Task<Never, Never>.sleep(nanoseconds: UInt64(interval * Double(NSEC_PER_SEC)))
    }

}
