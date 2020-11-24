//
//  FileDownload.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

struct FileDownload {

    var request: URLRequest
    var suggestedName: String?

    // Derived from headers
    var contentLength: Int? {
        return nil
    }

}

class FileDownloadState {

    enum FileDownloadError: Error {

        case restartResumeNotSupported
        case failedToCreateTemporaryFile

    }

    let download: FileDownload
    @Published var bytesDownloaded = 0
    @Published var filePath: String?
    @Published var error: Error?

    var fresh = true

    init(download: FileDownload) {
        self.download = download
    }

    func start() {
        if !fresh {
            error = FileDownloadError.restartResumeNotSupported
            return
        }
        fresh = false

        let fm = FileManager.default

        // download to temp file
        let name = UUID().uuidString
        let tempPath = fm.temporaryDirectory.appendingPathComponent(name).absoluteString
        print(#function, tempPath)

        if !fm.createFile(atPath: tempPath, contents: nil) {
            error = FileDownloadError.failedToCreateTemporaryFile
            return
        }

        // move temp file to downloads
        self.filePath = moveToTargetFolder()
    }

    private func createName() -> String {
        return "temp"
    }

    private func moveToTargetFolder() -> String {
        // Return a path in ~/Downloads
        return download.suggestedName ?? createName()
    }

}
