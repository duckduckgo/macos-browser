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

extension Task where Failure == Error {

    @discardableResult
    static func run(operation: @escaping @Sendable () async throws -> Success, completionHandler: (@MainActor (Result<Success, Failure>) -> Void)? = nil) -> Self {
        Task {
            let result = await Result<Success, Failure> {
                try await operation()
            }
            if let completionHandler {
                await MainActor.run {
                    completionHandler(result)
                }
            }
            return try result.get()
        }
    }

}

extension Task where Failure == Never {

    @discardableResult
    static func run(operation: @escaping @Sendable () async -> Success, completionHandler: (@MainActor (Success) -> Void)? = nil) -> Self {
        Task {
            let result = await operation()
            if let completionHandler {
                await MainActor.run {
                    completionHandler(result)
                }
            }
            return result
        }
    }

}
