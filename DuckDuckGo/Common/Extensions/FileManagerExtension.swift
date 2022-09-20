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

    func moveItem(at srcURL: URL, to destURL: URL, incrementingIndexIfExists flag: Bool, pathExtension: String? = nil) throws -> URL {
        return try self.perform(self.moveItem, from: srcURL, to: destURL, incrementingIndexIfExists: flag, pathExtension: pathExtension)
    }

    func copyItem(at srcURL: URL, to destURL: URL, incrementingIndexIfExists flag: Bool, pathExtension: String? = nil) throws -> URL {
        return try self.perform(self.copyItem, from: srcURL, to: destURL, incrementingIndexIfExists: flag, pathExtension: pathExtension)
    }

    private func perform(_ operation: (URL, URL) throws -> Void,
                         from srcURL: URL,
                         to destURL: URL,
                         incrementingIndexIfExists: Bool,
                         pathExtension: String?) throws -> URL {

        guard incrementingIndexIfExists else {
            try operation(srcURL, destURL)
            return destURL
        }

        var suffix = pathExtension ?? destURL.pathExtension
        if !suffix.hasPrefix(".") {
            suffix = "." + suffix
        }
        if !destURL.pathExtension.isEmpty {
            if !destURL.path.hasSuffix(suffix) {
                suffix = "." + destURL.pathExtension
            }
        } else {
            suffix = ""
        }

        let ownerDirectory = destURL.deletingLastPathComponent()
        let fileNameWithoutExtension = destURL.lastPathComponent.dropping(suffix: suffix)

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

    func temporaryDirectory(appropriateFor url: URL?) -> URL {
        do {
            struct ThrowableError: Error {}
            guard let url = url else { throw ThrowableError() }

            // this creates a temp diretory on the same volume as a requested url
            // "(A Document Being Saved By DuckDuckGo Privacy Browser N)" folder is created
            // on every call even if `create: false` is passed
            // and this starts to fail after reaching 1000 folders
            // so we'll create a temp directory, then delete it and
            // return its parent (actual temp dir)
            var tempURL = try self.url(for: .itemReplacementDirectory,
                                       in: .userDomainMask,
                                       appropriateFor: url,
                                       create: true)
            try self.removeItem(at: tempURL)

            tempURL = tempURL.deletingLastPathComponent()
            var isDir: ObjCBool = false
            guard self.fileExists(atPath: tempURL.path, isDirectory: &isDir),
                  isDir.boolValue,
                  try tempURL.resourceValues(forKeys: [.isWritableKey]).isWritable == true
            else { throw ThrowableError() }

            return tempURL

        } catch {
            return self.temporaryDirectory
        }
    }
    
}
