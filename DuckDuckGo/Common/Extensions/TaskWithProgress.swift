//
//  TaskWithProgress.swift
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

typealias TaskProgressProgressEvent<Success: Sendable, Failure: Error, ProgressUpdate> = TaskWithProgress<Success, Failure, ProgressUpdate>.ProgressEvent
typealias TaskProgress<Success: Sendable, Failure: Error, ProgressUpdate> = AsyncStream<TaskProgressProgressEvent<Success, Failure, ProgressUpdate>>
typealias TaskProgressUpdateCallback<Success: Sendable, Failure: Error, ProgressUpdate> = TaskWithProgress<Success, Failure, ProgressUpdate>.ProgressUpdateCallback

/// Used to run an async Task while tracking its completion progress
/// Usage:
/// ```
///   func doSomeOperation() -> TaskWithProgress<SomeResult, Error> {
///       .withProgress((total: 100, completed: 0)) { updateProgress in
///         try await part1()
///         updateProgress(50)
///
///         try await part2()
///         updateProgress(100)
///       }
///   }
/// ```
struct TaskWithProgress<Success, Failure, ProgressUpdate>: Sendable where Success: Sendable, Failure: Error {

    enum ProgressEvent {
        case progress(ProgressUpdate)
        case completed(Result<Success, Failure>)
    }

    let task: Task<Success, Failure>

    typealias Progress = AsyncStream<ProgressEvent>
    typealias ProgressUpdateCallback = (ProgressUpdate) throws -> Void

    let progress: Progress

    fileprivate init(task: Task<Success, Failure>, progress: Progress) {
        self.task = task
        self.progress = progress
    }

    /// The task's result
    var value: Success {
        get async throws {
            try await task.value
        }
    }

    /// The task's result
    var result: Result<Success, Failure> {
        get async {
            await task.result
        }
    }

    /// Cancel the Task
    func cancel() {
        task.cancel()
    }

    var isCancelled: Bool {
        task.isCancelled
    }

}

extension TaskWithProgress: Hashable {

    func hash(into hasher: inout Hasher) {
        task.hash(into: &hasher)
    }

    static func == (lhs: TaskWithProgress<Success, Failure, ProgressUpdate>, rhs: TaskWithProgress<Success, Failure, ProgressUpdate>) -> Bool {
        lhs.task == rhs.task
    }

}

extension TaskWithProgress where Failure == Never {

    /// The result from a nonthrowing task, after it completes.
    var value: Success {
        get async {
            await task.value
        }
    }

}

protocol AnyTask {
    associatedtype Success
    associatedtype Failure
}
extension Task: AnyTask {}
extension TaskWithProgress: AnyTask {}

extension AnyTask where Failure == Error {

    static func detachedWithProgress<ProgressUpdate>(_ progress: ProgressUpdate? = nil, priority: TaskPriority? = nil, do operation: @escaping @Sendable (@escaping TaskProgressUpdateCallback<Success, Failure, ProgressUpdate>) async throws -> Success) -> TaskWithProgress<Success, Failure, ProgressUpdate> {
        let (progressStream, progressContinuation) = TaskProgress<Success, Failure, ProgressUpdate>.makeStream()
        if let progress {
            progressContinuation.yield(.progress(progress))
        }

        let task = Task<Success, Failure>.detached {
            let updateProgressCallback: TaskProgressUpdateCallback<Success, Failure, ProgressUpdate> = { update in
                try Task.checkCancellation()
                progressContinuation.yield(.progress(update))
            }

            defer {
                progressContinuation.finish()
            }
            do {
                let result = try await operation(updateProgressCallback)
                progressContinuation.yield(.completed(.success(result)))

                return result
            } catch {
                progressContinuation.yield(.completed(.failure(error)))
                throw error
            }
        }

        return TaskWithProgress(task: task, progress: progressStream)
    }

}

extension AnyTask where Failure == Never {

    static func detachedWithProgress<ProgressUpdate>(_ progress: ProgressUpdate? = nil, completed: UInt? = nil, priority: TaskPriority? = nil, do operation: @escaping @Sendable (@escaping TaskProgressUpdateCallback<Success, Failure, ProgressUpdate>) async -> Success) -> TaskWithProgress<Success, Failure, ProgressUpdate> {
        let (progressStream, progressContinuation) = TaskProgress<Success, Failure, ProgressUpdate>.makeStream()
        if let progress {
            progressContinuation.yield(.progress(progress))
        }

        let task = Task<Success, Failure>.detached {
            let updateProgressCallback: TaskProgressUpdateCallback<Success, Failure, ProgressUpdate> = { update in
                try Task.checkCancellation()
                progressContinuation.yield(.progress(update))
            }

            let result = await operation(updateProgressCallback)
            progressContinuation.yield(.completed(.success(result)))
            progressContinuation.finish()

            return result
        }

        return TaskWithProgress(task: task, progress: progressStream)
    }

}
