//
//  FileDownloadTaskMock.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class FileDownloadTaskMock: FileDownloadTask {
    var isStarted = false
    var onStarted: ((FileDownloadTaskMock) -> Void)?
    var onLocalFileURLChosen: ((URL?, UTType?) -> Void)?
    var filename: String?

    override var suggestedFilename: String {
        filename ?? super.suggestedFilename
    }

    override func start() {
        isStarted = true
        onStarted?(self)
    }

    override func localFileURLCompletionHandler(localURL: URL?, fileType: UTType?) {
        onLocalFileURLChosen?(localURL, fileType)
    }

}

enum FileDownloadRequestMock: FileDownloadRequest {
    case download(URL?, prompt: Bool, task: ((FileDownloadRequestMock) -> FileDownloadTask?)? = nil)

    var shouldAlwaysPromptFileSaveLocation: Bool {
        switch self {
        case .download(_, prompt: let prompt, task: _):
            return prompt
        }
    }

    var sourceURL: URL? {
        switch self {
        case .download(let url, prompt: _, task: _):
            return url
        }
    }

    func downloadTask() -> FileDownloadTask? {
        switch self {
        case .download(_, prompt: _, task: let getTask) where getTask != nil:
            return getTask!(self)
        case .download:
            return FileDownloadTaskMock(download: self)
        }
    }
}
