//
//  WebKitDownloadTask.swift
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

protocol WebKitDownloadTaskProtocol: FileDownloadTask {
    func download(_ download: WebKitDownload, didReceiveResponse response: URLResponse)
    func download(_ download: WebKitDownload,
                  decideDestinationWithSuggestedFilename suggestedFilename: String?,
                  completionHandler: @escaping (/*allowOverwrite:*/ Bool, /*destination:*/ String?) -> Void)
    func download(_ download: WebKitDownload, didWriteData bytesWritten: UInt64, totalBytesWritten: UInt64, totalBytesExpectedToWrite: UInt64)

    func downloadDidFinish(_ download: WebKitDownload)
    func downloadDidCancel(_ download: WebKitDownload)
    func download(_ download: WebKitDownload, didFailWithError error: Error)
    func download(_ download: WebKitDownload,
                  didReceiveAuthenticationChallenge challenge: URLAuthenticationChallenge,
                  completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
}

final class WebKitDownloadTask: FileDownloadTask {

    private let wkDownload: WebKitDownload

    private var wkSuggestedFilename: String?
    override var suggestedFilename: String {
        guard let wkSuggestedFilename = wkSuggestedFilename,
              !wkSuggestedFilename.isEmpty
        else {
            return super.suggestedFilename
        }
        return wkSuggestedFilename
    }

    typealias DecideDestinationCompletionHandler = (/*allowOverwrite:*/ Bool, /*destination:*/ String?) -> Void
    private var decideDestinationCompletionHandler: DecideDestinationCompletionHandler?
    private var tempURL: URL?
    private var destinationURL: URL?

    init(download: WebKitDownload) {
        self.wkDownload = download
        super.init(download: FileDownload.wkDownload(download))
    }

    override func start() {
        self.progress.fileDownloadingSourceURL = wkDownload.request?.url
    }

    override func localFileURLCompletionHandler(localURL: URL?, fileType: UTType?) {
        dispatchPrecondition(condition: .onQueue(.main))

        let path: String?
        if let localURL = localURL {
            // _WKDownload doesn't increase file index counter if destination file exists
            // check if it exists and move the file incrementing index if needed on completion
            if FileManager.default.fileExists(atPath: localURL.path) {
                self.tempURL = localURL.deletingLastPathComponent()
                    .appendingPathComponent(.uniqueFilename(for: self.fileTypes?.first))
                path = self.tempURL?.path
            } else {
                path = localURL.path
            }

            self.progress.fileURL = path.map(URL.init(fileURLWithPath:))
            self.progress.publishIfNotPublished()

        } else {
            self.wkDownload.cancel()
            self.finish(with: .failure(.cancelled))
            path = nil
        }

        self.destinationURL = localURL
        self.decideDestinationCompletionHandler?(/*allowOverwrite:*/ false, path)
    }

    override func cancel() {
        wkDownload.cancel()
    }

}

extension WebKitDownloadTask: WebKitDownloadTaskProtocol {

    func download(_ download: WebKitDownload, didReceiveResponse response: URLResponse) {
        self.fileTypes = response.mimeType.flatMap(UTType.init(mimeType:)).map { [$0] }
        self.progress.totalUnitCount = response.expectedContentLength
    }

    func download(_ download: WebKitDownload,
                  decideDestinationWithSuggestedFilename suggestedFilename: String?,
                  completionHandler: @escaping DecideDestinationCompletionHandler) {
        self.wkSuggestedFilename = suggestedFilename
        self.decideDestinationCompletionHandler = completionHandler
        self.queryDestinationURL()
    }

    func download(_ download: WebKitDownload, didWriteData bytesWritten: UInt64, totalBytesWritten: UInt64, totalBytesExpectedToWrite: UInt64) {
        self.progress.totalUnitCount = Int64(totalBytesExpectedToWrite)
        self.progress.completedUnitCount = Int64(totalBytesWritten)
    }

    func downloadDidFinish(_ download: WebKitDownload) {
        guard var destinationURL = destinationURL else {
            self.finish(with: .failure(.failedToMoveFileToDownloads))
            return
        }

        if let tempURL = tempURL, tempURL != destinationURL {
            do {
                destinationURL = try FileManager.default.moveItem(at: tempURL,
                                                                  to: destinationURL,
                                                                  incrementingIndexIfExists: true)
            } catch {
                destinationURL = tempURL
            }
        }

        self.finish(with: .success(destinationURL))
    }

    func downloadDidCancel(_ download: WebKitDownload) {
        self.finish(with: .failure(.cancelled))
    }

    func download(_ download: WebKitDownload, didFailWithError error: Error) {
        self.finish(with: .failure(.failedToCompleteDownloadTask(underlyingError: error)))
    }

    func download(_ download: WebKitDownload,
                  didReceiveAuthenticationChallenge challenge: URLAuthenticationChallenge,
                  completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }
    
}
