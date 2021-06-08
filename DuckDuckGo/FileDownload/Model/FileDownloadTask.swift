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

import Foundation
import Combine

enum FileDownloadError: Error {
    case cancelled

    case restartResumeNotSupported
    case failedToCreateTemporaryFile
    case failedToCreateTemporaryDir
    case failedToMoveFileToDownloads
    case failedToCompleteDownloadTask(underlyingError: Error)

}

protocol FileDownloadTaskDelegate: AnyObject {
    func fileDownloadTaskNeedsDestinationURL(_ task: FileDownloadTask, completionHandler: @escaping (URL?, UTType?) -> Void)
    func fileDownloadTask(_ task: FileDownloadTask, didFinishWith result: Result<URL, FileDownloadError>)
}

internal class FileDownloadTask: NSObject {
    let download: FileDownloadRequest

    private static let defaultFileName = "Unknown"

    /// Tries to use the file name part of the URL, if available, adjusting for content type, if available.
    var suggestedFilename: String {
        let url = self.download.sourceURL

        var filename: String
        if let url = url,
           !url.pathComponents.isEmpty,
           url.pathComponents != [ "/" ] {

            filename = url.lastPathComponent
        } else {
            filename = url?.host?.drop(prefix: "www.").replacingOccurrences(of: ".", with: "_") ?? ""
        }
        if filename.isEmpty {
            filename = Self.defaultFileName
        }

        if let ext = self.fileTypes?.first?.fileExtension,
           !filename.hasSuffix("." + ext) {
            // there is a more appropriate extension, so use it
            filename += "." + ext
        }
        return filename
    }

    var fileTypes: [UTType]?
    let progress: Progress

    private lazy var future: Future<URL, FileDownloadError> = {
        dispatchPrecondition(condition: .onQueue(.main))
        let future = Future<URL, FileDownloadError> { self.fulfill = $0 }
        assert(self.fulfill != nil)
        return future
    }()

    private var fulfill: Future<URL, FileDownloadError>.Promise?
    var output: AnyPublisher<URL, FileDownloadError> { future.eraseToAnyPublisher() }

    var postflight: FileDownloadPostflight?

    private weak var delegate: FileDownloadTaskDelegate?

    init(download: FileDownloadRequest) {
        self.download = download
        self.progress = Progress(parent: nil, userInfo: [
            .fileOperationKindKey: Progress.FileOperationKind.downloading
        ])
        super.init()

        progress.kind = .file
        progress.totalUnitCount = -1
        progress.completedUnitCount = 0

        progress.isPausable = false
        progress.isCancellable = true
        progress.cancellationHandler = { [weak self] in
            self?.cancel()
        }
    }

    final func start(delegate: FileDownloadTaskDelegate) {
        _=future
        self.delegate = delegate
        start()
    }

    func start() {
        self.queryDestinationURL()
    }

    func _finish(with result: Result<URL, FileDownloadError>) { // swiftlint:disable:this identifier_name
        dispatchPrecondition(condition: .onQueue(.main))
        guard let fulfill = self.fulfill else {
            // already finished
            return
        }

        if case .success(let url) = result {
            if progress.fileURL != url {
                progress.fileURL = url
            }
            if self.progress.totalUnitCount == -1 {
                self.progress.totalUnitCount = 1
            }
            self.progress.completedUnitCount = self.progress.totalUnitCount
        }

        self.progress.unpublishIfNeeded()

        self.delegate?.fileDownloadTask(self, didFinishWith: result)
        self.fulfill = nil
        fulfill(result)
    }

    final func finish(with result: Result<URL, FileDownloadError>) {
        if Thread.isMainThread {
            _finish(with: result)
        } else {
            DispatchQueue.main.async {
                self._finish(with: result)
            }
        }
    }

    final func queryDestinationURL() {
        delegate?.fileDownloadTaskNeedsDestinationURL(self, completionHandler: self.localFileURLCompletionHandler)
    }

    func localFileURLCompletionHandler(localURL: URL?, fileType: UTType?) {
    }

    func cancel() {
    }

    deinit {
        self.progress.unpublishIfNeeded()
        assert(fulfill == nil, "FileDownloadTask is deallocated without finish(with:) been called")
    }

}
