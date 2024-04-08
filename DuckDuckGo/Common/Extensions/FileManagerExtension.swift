//
//  FileManagerExtension.swift
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

import Common
import Foundation

extension FileManager {

    @discardableResult
    func moveItem(at srcURL: URL, to destURL: URL, incrementingIndexIfExists flag: Bool, pathExtension: String? = nil) throws -> URL {
        guard srcURL != destURL else { return destURL }
        guard flag else {
            try moveItem(at: srcURL, to: destURL)
            return destURL
        }
        return try withNonExistentUrl(for: destURL, incrementingIndexIfExistsUpTo: 10000, pathExtension: pathExtension) { url in
            try moveItem(at: srcURL, to: url)
            return url
        }
    }

    @discardableResult
    func copyItem(at srcURL: URL, to destURL: URL, incrementingIndexIfExists flag: Bool, pathExtension: String? = nil) throws -> URL {
        guard srcURL != destURL else { return destURL }
        guard flag else {
            try moveItem(at: srcURL, to: destURL)
            return destURL
        }
        return try withNonExistentUrl(for: destURL, incrementingIndexIfExistsUpTo: flag ? 10000 : 0, pathExtension: pathExtension) { url in
            try copyItem(at: srcURL, to: url)
            return url
        }
    }

    func withNonExistentUrl<T>(for desiredURL: URL,
                               incrementingIndexIfExistsUpTo limit: UInt,
                               pathExtension: String? = nil,
                               continueOn shouldContinue: (Error) -> Bool = { ($0 as? CocoaError)?.code == .fileWriteFileExists },
                               perform operation: (URL) throws -> T) throws -> T {

        var suffix = pathExtension ?? desiredURL.pathExtension
        if !suffix.hasPrefix(".") {
            suffix = "." + suffix
        }
        if !desiredURL.pathExtension.isEmpty {
            if !desiredURL.path.hasSuffix(suffix) {
                suffix = "." + desiredURL.pathExtension
            }
        } else {
            suffix = ""
        }

        let ownerDirectory = desiredURL.deletingLastPathComponent()
        let fileNameWithoutExtension = desiredURL.lastPathComponent.dropping(suffix: suffix)

        var index: UInt = 0
        repeat {
            let desiredURL: URL = {
                // Zero means we haven't tried anything yet, so use the suggested name.
                // Otherwise, simply append the file name with the copy number.
                guard index > 0 else { return desiredURL }
                return ownerDirectory.appendingPathComponent("\(fileNameWithoutExtension) \(index)\(suffix)")
            }()

            if !self.fileExists(atPath: desiredURL.path) {
                do {
                    return try operation(desiredURL)
                } catch {
                    guard shouldContinue(error) else { throw error }
                    // This is expected, as moveItem throws an error if the file already exists
                    index += 1
                }
            }
            index += 1
        } while index <= limit
        // If it gets beyond the limit then chances are something else is wrong
        os_log("Failed to move file to %s, attempt: %d", type: .error, desiredURL.deletingLastPathComponent().path, index)
        throw CocoaError(.fileWriteFileExists)
    }

    func isInTrash(_ url: URL) -> Bool {
        let resolvedUrl = url.resolvingSymlinksInPath()
        guard let trashUrl = (try? self.url(for: .trashDirectory, in: .allDomainsMask, appropriateFor: resolvedUrl, create: false))
                ?? urls(for: .trashDirectory, in: .userDomainMask).first else { return false }

        return resolvedUrl.path.hasPrefix(trashUrl.path)
    }

}
