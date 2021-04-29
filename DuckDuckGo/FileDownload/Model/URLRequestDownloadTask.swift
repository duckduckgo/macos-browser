//
//  URLRequestDownloadTask.swift
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
import Combine
import os

final class URLRequestDownloadTask: NSObject, FileDownloadTask {
    private var localFileURLCallback: LocalFileURLCallback?
    private var completion: ((Result<URL, FileDownloadError>) -> Void)?
    private var localFileURL: URL?

    private var session: URLSession?
    private let request: URLRequest
    private var task: URLSessionTask?

    private(set) var fileTypes: [UTType]?
    private(set) var suggestedFilename: String?
    private var dispatchGroup: DispatchGroup?

    @Published var bytesDownloaded: Int64 = 0

    private var savedFileURL: URL?
    private var error: Error?

    init(session: URLSession? = nil, request: URLRequest) {
        self.session = session
        self.request = request
    }

    func start(localFileURLCallback: @escaping LocalFileURLCallback, completion: @escaping (Result<URL, FileDownloadError>) -> Void) {
        self.localFileURLCallback = localFileURLCallback
        self.completion = completion

        session = URLSession(configuration: session?.configuration ?? .default, delegate: self, delegateQueue: nil)
        task = session!.downloadTask(with: request)

        let dispatchGroup = DispatchGroup()
        self.dispatchGroup = dispatchGroup
        // start download asynchronously while user chooses a filename
        dispatchGroup.enter()
        task!.resume()

        self.suggestedFilename = self.bestFileName()
        dispatchGroup.enter()
        localFileURLCallback(self) { url in
            // file save destination was chosen (or default)
            defer {
                dispatchGroup.leave()
            }
            guard let url = url else {
                self.task?.cancel()
                self.completion?(.failure(.cancelled))
                return
            }

            self.localFileURL = url
        }

        dispatchGroup.notify(queue: .global()) {
            var result: Result<URL, FileDownloadError> = .failure(.cancelled)

            if let localFileURL = self.localFileURL,
               let url = self.savedFileURL {

                do {
                    let resultURL = try FileManager.default.moveItem(at: url,
                                                                     to: localFileURL,
                                                                     incrementingIndexIfExists: true)
                    result = .success(resultURL)
                } catch {
                    result = .failure(.failedToMoveFileToDownloads)
                }
            } else if let error = self.error {
                result = .failure(.failedToCompleteDownloadTask(underlyingError: error))
            }

            DispatchQueue.main.async {
                self.completion?(result)
            }
        }

    }

    private func bestFileName() -> String? {
        if let suggestedFilename = self.suggestedFilename, !suggestedFilename.isEmpty {
            return suggestedFilename
        } else {
            return fileNameFromURL()
        }
    }

    /// Tries to use the file name part of the URL, if available, adjusting for content type, if available.
    private func fileNameFromURL() -> String? {
        guard let url = request.url,
              !url.pathComponents.isEmpty,
              url.pathComponents != [ "/" ]
        else {
            return request.url?.host?.drop(prefix: "www.").replacingOccurrences(of: ".", with: "_")
        }

        if let ext = self.fileTypes?.first?.fileExtension,
           url.pathExtension != ext {

            // there is a more appropriate extension, so use it
            return url.lastPathComponent + "." + ext
        }

        return url.lastPathComponent
    }

    /// Based on Content-Length header, if avialable.
    var contentLength: Int? {
        guard let contentLength = request.allHTTPHeaderFields?["Content-Length"] else { return nil }
        return Int(contentLength)
    }

}

extension URLRequestDownloadTask: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.error = error
        self.dispatchGroup?.leave()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // instantly move the downloaded file to a safe location before it gets removed
        let fm = FileManager.default
        let tmpURL = fm.temporaryDirectory.appendingPathComponent(.uniqueFilename())
        try? fm.moveItem(at: location, to: tmpURL)
        self.savedFileURL = tmpURL
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        bytesDownloaded = totalBytesWritten
    }

}
