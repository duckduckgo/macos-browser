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

final class URLRequestDownloadTask: FileDownloadTask {
    private var localFileURL: URL?

    private var session: URLSession?
    private let request: URLRequest
    private var task: URLSessionTask?

    private var downloadedFileLocationCancellable: AnyCancellable?

    private var downloadedFile: DownloadedFile? {
        didSet {
            guard let downloadedFile = downloadedFile else { return }
            downloadedFileLocationCancellable = downloadedFile.$url.sink { [weak self] url in
                #warning("if newURL is in Trash stop download")
                if url?.path.contains("/.Trash/") == true {
                    self?.cancel()
                }
            }
        }
    }

    @Published var bytesDownloaded: Int64 = 0

    private var savedFileURL: URL?
    private var error: Error?

    init(download: FileDownload, session: URLSession? = nil, request: URLRequest) {
        self.session = session
        self.request = request

        super.init(download: download)
    }

    override func start(delegate: FileDownloadTaskDelegate) {
        super.start(delegate: delegate)

        session = URLSession(configuration: session?.configuration ?? .default, delegate: self, delegateQueue: nil)
        task = session!.dataTask(with: request)

        self.suggestedFilename = self.bestFileName()

        task?.resume()
    }

    override func cancel() {
        self.task?.cancel()
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

extension URLRequestDownloadTask: URLSessionDataDelegate {

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

        let downloadLocation = DownloadPreferences().selectedDownloadLocation
        let fm = FileManager.default
        let tempDir = (try? fm.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: downloadLocation, create: false))
            ?? fm.temporaryDirectory

        let tempURL = tempDir.appendingPathComponent(.uniqueFilename())

        self.downloadedFile = DownloadedFile(url: tempURL, expectedSize: response.expectedContentLength)
        self.suggestedFilename = response.suggestedFilename ?? self.suggestedFilename
        self.fileTypes = response.mimeType.flatMap(UTType.init(mimeType:)).map { [$0] }

        DispatchQueue.main.async { [weak self, dataTask] in
            guard let self = self else {
                completionHandler(.cancel)
                return
            }
            completionHandler(.allow)

            self.delegate?.fileDownloadTaskNeedsDestinationURL(self) { url in
                if let url = url, let downloadedFile = self.downloadedFile {
                    self.localFileURL = url
                    switch dataTask.state {
                    case .completed:
                        do {
                            let finalURL = try downloadedFile.move(to: url, incrementingIndexIfExists: true)
                            self.delegate?.fileDownloadTask(self, didFinishWith: .success(finalURL))
                        } catch {
                            self.delegate?.fileDownloadTask(self, didFinishWith: .failure(.failedToMoveFileToDownloads))
                        }
                    case .running, .suspended:
                        let downloadURL = url.appendingPathExtension("duckDownload")
                        _=try? self.downloadedFile?.move(to: downloadURL, incrementingIndexIfExists: true)
                    case .canceling:
                        break
                    @unknown default:
                        break
                    }

                } else {
                    dataTask.cancel()
                    try? self.downloadedFile?.delete()
                    self.delegate?.fileDownloadTask(self, didFinishWith: .failure(.cancelled))
                }
            }
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.downloadedFile?.write(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.downloadedFile?.close()

        if let error = error {
            try? self.downloadedFile?.delete()
            DispatchQueue.main.async {
                self.delegate?.fileDownloadTask(self, didFinishWith: .failure(.failedToCompleteDownloadTask(underlyingError: error)))
            }

        } else if let destURL = DispatchQueue.main.sync(execute: { self.localFileURL }) {
            do {
                guard let finalURL = try self.downloadedFile?.move(to: destURL, incrementingIndexIfExists: true) else {
                    throw FileDownloadError.cancelled
                }
                DispatchQueue.main.async {
                    self.delegate?.fileDownloadTask(self, didFinishWith: .success(finalURL))
                }
            } catch {
                try? self.downloadedFile?.delete()
                DispatchQueue.main.async {
                    self.delegate?.fileDownloadTask(self, didFinishWith: .failure(.failedToMoveFileToDownloads))
                }
            }
        }
    }

}
