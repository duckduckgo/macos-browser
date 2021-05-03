//
//  LocalFileSaveTask.swift
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

final class LocalFileSaveTask: FileDownloadTask {

    let url: URL

    override var suggestedFilename: String? {
        get {
            url.lastPathComponent
        }
        set { }
    }

    init(download: FileDownload, url: URL, fileType: UTType?) {
        self.url = url
        super.init(download: download)
        
        self.fileTypes = fileType.map { [$0] }
    }

    override func start(delegate: FileDownloadTaskDelegate) {
        super.start(delegate: delegate)

        delegate.fileDownloadTaskNeedsDestinationURL(self, completionHandler: self.localFileURLCompletionHandler)
    }

    private func localFileURLCompletionHandler(_ destURL: URL?) {
        guard let destURL = destURL else {
            delegate?.fileDownloadTask(self, didFinishWith: .failure(.cancelled))
            return
        }

        do {
            let resultURL = try FileManager.default.copyItem(at: self.url, to: destURL, incrementingIndexIfExists: true)
            delegate?.fileDownloadTask(self, didFinishWith: .success(resultURL))
        } catch {
            delegate?.fileDownloadTask(self, didFinishWith: .failure(.failedToMoveFileToDownloads))
        }
    }

}
