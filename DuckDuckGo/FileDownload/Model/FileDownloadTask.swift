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
    let download: FileDownload

    static let defaultFileName = "Unknown"

    /// Tries to use the file name part of the URL, if available, adjusting for content type, if available.
    var suggestedFilename: String {
        guard let url = self.download.sourceURL else { return Self.defaultFileName }
        guard !url.pathComponents.isEmpty, url.pathComponents != [ "/" ] else {
            return url.host?.drop(prefix: "www.").replacingOccurrences(of: ".", with: "_")
                ?? Self.defaultFileName
        }

        if let ext = self.fileTypes?.first?.fileExtension,
           url.pathExtension != ext {

            // there is a more appropriate extension, so use it
            return url.lastPathComponent + "." + ext
        }

        return url.lastPathComponent
    }

    var fileTypes: [UTType]?
    let progress: Progress

    weak var delegate: FileDownloadTaskDelegate?

    init(download: FileDownload) {
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

    func start(delegate: FileDownloadTaskDelegate) {
        self.delegate = delegate
    }

    func cancel() {
    }

    deinit {
        self.progress.unpublishIfNeeded()
    }

}
