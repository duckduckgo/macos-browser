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

    var suggestedFilename: String?
    var fileTypes: [UTType]?

    weak var delegate: FileDownloadTaskDelegate?

    init(download: FileDownload) {
        self.download = download
    }

    func start(delegate: FileDownloadTaskDelegate) {
        self.delegate = delegate
    }

    func cancel() {
    }

}
