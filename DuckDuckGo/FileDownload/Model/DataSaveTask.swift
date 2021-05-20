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

    private var dataSuggestedFilename: String?
    override var suggestedFilename: String {
        guard let dataSuggestedFilename = dataSuggestedFilename,
              !dataSuggestedFilename.isEmpty
        else {
            return super.suggestedFilename
        }
        return dataSuggestedFilename
    }

    let data: Data

    init(download: FileDownloadRequest, data: Data, mimeType: String? = nil, suggestedFilename: String? = nil) {
        self.data = data
        super.init(download: download)

        self.fileTypes = mimeType.flatMap(UTType.init(mimeType:)).map { [$0] }
        self.dataSuggestedFilename = suggestedFilename
    }

    override func localFileURLCompletionHandler(localURL: URL?, fileType: UTType?) {
        guard let localURL = localURL else {
            finish(with: .failure(.cancelled))
            return
        }
        let fileSize = Int64(self.data.count)
        self.progress.totalUnitCount = fileSize
        self.progress.fileDownloadingSourceURL = self.download.sourceURL
        self.progress.fileURL = localURL
        self.progress.publishIfNotPublished()

        DispatchQueue.global().async {
            let fm = FileManager()
            let temp = fm.temporaryDirectory.appendingPathComponent(.uniqueFilename())
            let saved = fm.createFile(atPath: temp.path, contents: self.data, attributes: nil)
            var outURL: URL?

            if saved {
                outURL = try? fm.moveItem(at: temp, to: localURL, incrementingIndexIfExists: true)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.progress.completedUnitCount = self.progress.totalUnitCount
                self.progress.unpublishIfNeeded()

                if let url = outURL {
                    self.finish(with: .success(url))
                } else {
                    self.finish(with: .failure(saved ? .failedToMoveFileToDownloads : .failedToCreateTemporaryFile))
                }
            }
        }
    }

}
