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

class FileDownloadState: NSObject {

    enum FileDownloadError: Error {

        case restartResumeNotSupported
        case failedToCreateTemporaryFile
        case failedToCreateTemporaryDir
        case failedToGetDownloadsFolder
        case failedToMoveFileToDownloads
        case failedToCreateTargetFileName

    }

    let download: FileDownload

    @Published var bytesDownloaded: Int64 = 0
    @Published var filePath: String?
    @Published var error: Error?

    var session: URLSession?

    init(download: FileDownload) {
        self.download = download
    }

    func start() {
        if session != nil {
            error = FileDownloadError.restartResumeNotSupported
            return
        }
        session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        session?.downloadTask(with: download.request).resume()
    }

    private func createName() -> String {
        return "temp"
    }

    private func moveToTargetFolder(from: URL) -> String? {
        let fm = FileManager.default
        let fileName = download.suggestedName ?? createName()

        let documentFolders = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsUrl = documentFolders.first else {
            error = FileDownloadError.failedToGetDownloadsFolder
            return nil
        }

        var copy = 0
        while copy < 10 {

            let fileInDownloads = availableFile(in: documentsUrl, named: fileName, copy: copy)
            do {
                try fm.moveItem(at: from, to: fileInDownloads)
                print(#function, fileInDownloads.path)
                return fileInDownloads.path
            } catch {
                self.error = FileDownloadError.failedToMoveFileToDownloads
            }
            copy += 1
        }

        error = FileDownloadError.failedToCreateTargetFileName
        return nil
    }

    private func availableFile(in folder: URL, named name: String, copy: Int) -> URL {
        let path = copy == 0 ? name : "\(copy)_\(name)"
        let file = folder.appendingPathComponent(path)
        return file
    }

}

extension FileDownloadState: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print(#function, location)

        // Don't reassign nil and trigger an event
        if let filePath = moveToTargetFolder(from: location) {
            self.filePath = filePath
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        bytesDownloaded = totalBytesWritten
    }

}

extension URL {

    var fileExists: Bool {
        return (try? checkResourceIsReachable()) ?? false
    }

}
