//
//  FileDownloadState.swift
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

    private func createFileName(fileType: String?) -> String {
        let suffix: String
        if let fileType = fileType {
            suffix = "." + fileType
        } else {
            suffix = ""
        }

        let prefix: String
        if let host = download.request.url?.host?.drop(prefix: "www.") {
            prefix = host + "_"
        } else {
            prefix = ""
        }

        return prefix + UUID().uuidString + suffix
    }

    /// Tries to use the file name part of the URL, if available, adjusting for content type, if available.
    private func fileNameFromURL(fileType: String?) -> String? {
        guard let url = download.request.url, !url.pathExtension.isEmpty else { return nil }
        let suffix: String
        if let fileType = fileType,
           !url.lastPathComponent.hasSuffix("." + fileType) {
            suffix = "." + fileType
        } else {
            suffix = ""
        }

        return url.lastPathComponent + suffix
    }

    private func moveToTargetFolder(from url: URL, withFileName fileName: String) -> String? {

        let fm = FileManager.default
        let folders = fm.urls(for: .downloadsDirectory, in: .userDomainMask)
        guard let folderUrl = folders.first else {
            error = FileDownloadError.failedToGetDownloadsFolder
            return nil
        }

        var copy = 0
        while copy < 10 {

            let fileInDownloads = incrementFileName(in: folderUrl, named: fileName, copy: copy)
            do {
                try fm.moveItem(at: url, to: fileInDownloads)
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

    private func incrementFileName(in folder: URL, named name: String, copy: Int) -> URL {
        // Zero means we haven't tried anything yet, so use the suggested name.  Otherwise, simply prefix the file name with the copy number.
        let path = copy == 0 ? name : "\(copy)_\(name)"
        let file = folder.appendingPathComponent(path)
        return file
    }

}

extension FileDownloadState: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print(#function, location)

        let contentType = downloadTask.response?.contentType

        // e.g. text/html; charset=UTF-8 -> html
        let fileType = contentType?.components(separatedBy: "/").last?.components(separatedBy: ";").first

        let fileName = download.suggestedName ??
            fileNameFromURL(fileType: fileType) ??
            createFileName(fileType: fileType)

        print(#function, "fileName", fileName)

        // Don't reassign nil and trigger an event
        if let filePath = moveToTargetFolder(from: location, withFileName: fileName) {
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

extension URLResponse {

    var contentType: String? {
        return (self as? HTTPURLResponse)?.allHeaderFields["Content-Type"] as? String
    }

}
