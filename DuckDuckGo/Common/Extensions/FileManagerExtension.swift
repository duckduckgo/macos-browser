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

import Foundation
import os

extension FileManager {

    func moveItem(at srcURL: URL, to destURL: URL, incrementingIndexIfExists flag: Bool) throws -> URL {
        return try self.perform(self.moveItem, from: srcURL, to: destURL, incrementingIndexIfExists: flag)
    }

    func copyItem(at srcURL: URL, to destURL: URL, incrementingIndexIfExists flag: Bool) throws -> URL {
        return try self.perform(self.copyItem, from: srcURL, to: destURL, incrementingIndexIfExists: flag)
    }

    private func perform(_ operation: (URL, URL) throws -> Void,
                         from srcURL: URL,
                         to destURL: URL,
                         incrementingIndexIfExists: Bool) throws -> URL {

        guard incrementingIndexIfExists else {
            try operation(srcURL, destURL)
            return destURL
        }

        var suffix = destURL.pathExtension
        if !suffix.isEmpty {
            suffix = "." + suffix
        }
        let ownerDirectory = destURL.deletingLastPathComponent()
        let fileNameWithoutExtension = destURL.deletingPathExtension().lastPathComponent

        for copy in 0... {
            let destURL: URL = {
                // Zero means we haven't tried anything yet, so use the suggested name.
                // Otherwise, simply append the file name with the copy number.
                guard copy > 0 else { return destURL }
                return ownerDirectory.appendingPathComponent("\(fileNameWithoutExtension) \(copy)\(suffix)")
            }()

            do {
                try operation(srcURL, destURL)
                return destURL

            } catch CocoaError.fileWriteFileExists {
                // This is expected, as moveItem throws an error if the file already exists
                guard copy <= 1000 else {
                    // If it gets to 1000 of these then chances are something else is wrong
                    os_log("Failed to move file to Downloads folder, attempt %d", type: .error, copy)
                    throw CocoaError(.fileWriteFileExists)
                }
            } catch {
                Pixel.fire(.debug(event: .fileMoveToDownloadsFailed, error: error))
                throw error
            }
        }
        fatalError("Unexpected flow")
    }

    func setFractionCompleted(_ fraction: Double?, at url: URL) throws {
        var attributes = try self.attributesOfItem(atPath: url.path)

        var extendedAttributes = attributes[.extended] as? [FileAttributeKey: Any] ?? [:]
        extendedAttributes[.fractionCompleted] = fraction.map { "\($0)" }?.data(using: .utf8)

        attributes[.extended] = extendedAttributes
        attributes[.creationDate] = Date.magicCreationDateForFileProgress

        try self.setAttributes(attributes, ofItemAtPath: url.path)
    }

}

private extension FileAttributeKey {

    static let extended = FileAttributeKey("NSFileExtendedAttributes")
    static let fractionCompleted = FileAttributeKey("com.apple.progress.fractionCompleted")
    static let quarantine = FileAttributeKey("com.apple.quarantine")

}

private extension Date {

    static let magicCreationDateForFileProgress = Date(timeIntervalSince1970: 443779200)

}
