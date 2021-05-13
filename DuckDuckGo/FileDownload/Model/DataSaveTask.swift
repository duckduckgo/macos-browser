//
//  DataSaveTask.swift
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

final class DataSaveTask: FileDownloadTask {

    let data: Data

    init(download: FileDownload, data: Data, mimeType: String? = nil, suggestedFilename: String? = nil) {
        self.data = data
        super.init(download: download)

        self.fileTypes = mimeType.flatMap(UTType.init(mimeType:)).map { [$0] }
        self.suggestedFilename = suggestedFilename
    }

    override func start(delegate: FileDownloadTaskDelegate) {
        super.start(delegate: delegate)
        delegate.fileDownloadTaskNeedsDestinationURL(self, completionHandler: self.localFileURLCompletionHandler)
    }

    private func localFileURLCompletionHandler(_ localURL: URL?, _: UTType?) {
        guard let localURL = localURL else {
            delegate?.fileDownloadTask(self, didFinishWith: .failure(.cancelled))
            return
        }

        DispatchQueue.global().async {
            let fm = FileManager()
            let temp = fm.temporaryDirectory.appendingPathComponent(.uniqueFilename())
            let saved = fm.createFile(atPath: temp.path, contents: self.data, attributes: nil)
            var outURL: URL?

            if saved {
                outURL = try? fm.moveItem(at: temp, to: localURL, incrementingIndexIfExists: true)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self, let delegate = self.delegate else { return }

                if let url = outURL {
                    delegate.fileDownloadTask(self, didFinishWith: .success(url))
                } else {
                    delegate.fileDownloadTask(self, didFinishWith: .failure(saved ? .failedToMoveFileToDownloads
                                                                                : .failedToCreateTemporaryFile))
                }
            }
        }
    }

}
