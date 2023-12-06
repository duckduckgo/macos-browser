//
//  TemporaryFileHandler.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

final class TemporaryFileHandler {

    let fileURL: URL
    let temporaryFileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL

        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fileExtension = fileURL.pathExtension
        let newFileName = UUID().uuidString
        let finalTemporaryFileURL = temporaryDirectoryURL.appendingPathComponent(newFileName).appendingPathExtension(fileExtension)

        self.temporaryFileURL = finalTemporaryFileURL
    }

    deinit {
        deleteTemporarilyCopiedFile()
    }

    func withTemporaryFile<T>(_ closure: (URL) throws -> T) throws -> T {
        let temporaryFileURL = try copyFileToTemporaryDirectory()
        defer { deleteTemporarilyCopiedFile() }
        return try closure(temporaryFileURL)
    }

    func copyFileToTemporaryDirectory() throws -> URL {
        try FileManager.default.copyItem(at: fileURL, to: temporaryFileURL)

        return temporaryFileURL
    }

    func deleteTemporarilyCopiedFile() {
        try? FileManager.default.removeItem(at: temporaryFileURL)
    }

}

extension URL {

    func withTemporaryFile<T>(_ closure: (URL) throws -> T) throws -> T {
        let handler = TemporaryFileHandler(fileURL: self)
        return try handler.withTemporaryFile(closure)
    }

}
