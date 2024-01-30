//
//  ProgressDownloadOperation.swift
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

import Foundation

/// A class that wraps a download operation and notify subscribers of progress.
final class ProgressDownloadOperation {
    private let destURL: URL
    private let block: () throws -> Void

    init(destURL: URL, block: @escaping () throws -> Void) {
        self.destURL = destURL
        self.block = block
    }

    /// Starts an operation with progress and publish progress changes.
    func start() throws {
        let progress = Progress(
            totalUnitCount: 1,
            fileOperationKind: .downloading,
            kind: .file,
            isPausable: false,
            isCancellable: false,
            fileURL: destURL
        )

        defer { progress.unpublish() }
        progress.publish()

        do {
            try block()
            progress.completedUnitCount = progress.totalUnitCount
        } catch {
            throw error
        }
    }
}
