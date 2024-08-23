//
//  BinaryOwnershipChecker.swift
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
import Common

protocol BinaryOwnershipChecking {
    func isCurrentUserOwner() -> Bool
}

/// A class responsible for checking whether the current user owns the binary of the app.
/// The result is cached after the first check to avoid repeated file system access.
final class BinaryOwnershipChecker: BinaryOwnershipChecking {

    private let fileManager: FileManager
    private var ownershipCache: Bool?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Checks if the current user owns the binary of the currently running app.
    /// The method caches the result after the first check to improve performance on subsequent calls.
    /// - Returns: `true` if the current user is the owner, `false` otherwise.
    func isCurrentUserOwner() -> Bool {
        if let cachedResult = ownershipCache {
            return cachedResult
        }

        guard let binaryPath = Bundle.main.executablePath else {
            os_log("Failed to get the binary path", log: .updates)
            ownershipCache = false
            return false
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: binaryPath)
            if let ownerID = attributes[FileAttributeKey.ownerAccountID] as? NSNumber {
                let isOwner = ownerID.intValue == getuid()
                ownershipCache = isOwner
                return isOwner
            }
        } catch {
            os_log("Failed to get binary file attributes: %{public}@",
                   log: .updates,
                   error.localizedDescription)
        }

        ownershipCache = false
        return false
    }
}
