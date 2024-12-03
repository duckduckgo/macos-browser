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
import os.log

extension FileManager {

#if !SANDBOX_TEST_TOOL
    func configurationDirectory() -> URL {
        let fm = FileManager.default

        guard let dir = fm.containerURL(forSecurityApplicationGroupIdentifier: Bundle.main.appGroup(bundle: .appConfiguration)) else {
            fatalError("Failed to get application group URL")
        }
        let subDir = dir.appendingPathComponent("Configuration")

        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: subDir.path, isDirectory: &isDir) || !isDir.boolValue {
            if !isDir.boolValue {
                try? fm.removeItem(at: subDir)
            }
            do {
                try fm.createDirectory(at: subDir, withIntermediateDirectories: true, attributes: nil)
                isDir = true
            } catch {
                fatalError("Failed to create directory at \(subDir.path)")
            }
        }
        return subDir
    }
#endif

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
        Logger.general.error("Failed to move file to \(desiredURL.deletingLastPathComponent().path), attempt: \(index)")
        throw CocoaError(.fileWriteFileExists)
    }

    func isInTrash(_ url: URL) -> Bool {
        let resolvedUrl = url.resolvingSymlinksInPath()
        guard let trashUrl = (try? self.url(for: .trashDirectory, in: .allDomainsMask, appropriateFor: resolvedUrl, create: false))
                ?? urls(for: .trashDirectory, in: .userDomainMask).first else { return false }

        return resolvedUrl.path.hasPrefix(trashUrl.path)
    }

    /// Check if location pointed by the URL is writable by writing an empty data to it and removing the file if write succeeds
    /// - Throws error if writing to the location fails
    func checkWritability(_ url: URL) throws {
        if fileExists(atPath: url.path), isWritableFile(atPath: url.path) {
            return // we can write
        } else {
            // either we can‘t write or there‘s no file at the url – try writing throwing access error if no permission
            try Data().write(to: url)
            try removeItem(at: url)
        }
    }

}
