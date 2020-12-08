//
//  FileDownloadTask.swift
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

import Combine
import os

class FileDownloadTask: NSObject {

    enum FileDownloadError: Error {

        case restartResumeNotSupported
        case failedToCreateTemporaryFile
        case failedToCreateTemporaryDir
        case failedToMoveFileToDownloads
        case failedToCompleteDownloadTask

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

}

extension FileDownloadTask: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        os_log("download task failed %s", type: .error, error?.localizedDescription ?? "")
        self.error = FileDownloadError.failedToCompleteDownloadTask
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {

        let fileName = download.bestFileName(mimeType: downloadTask.response?.mimeType)

        // Don't reassign nil and trigger an event
        if let filePath = location.moveToDownloadsFolder(withFileName: fileName) {
            self.filePath = filePath
        } else {
            error = FileDownloadError.failedToMoveFileToDownloads
        }

    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        bytesDownloaded = totalBytesWritten
    }

}
