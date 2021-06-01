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

    override var suggestedFilename: String {
        url.lastPathComponent
    }

    init(download: FileDownloadRequest, url: URL, fileType: UTType?) {
        self.url = url
        super.init(download: download)
        
        self.fileTypes = fileType.map { [$0] }
    }

    override func localFileURLCompletionHandler(localURL: URL?, fileType: UTType?) {
        guard let destURL = localURL else {
            finish(with: .failure(.cancelled))
            return
        }

        do {
            let fileSize = Int64((try? self.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 100)
            self.progress.totalUnitCount = fileSize
            self.progress.fileDownloadingSourceURL = self.url
            self.progress.fileURL = destURL
            self.progress.publishIfNotPublished()
            defer {
                self.progress.unpublishIfNeeded()
            }

            let resultURL = try FileManager.default.copyItem(at: self.url, to: destURL, incrementingIndexIfExists: true)
            self.progress.completedUnitCount = fileSize

            finish(with: .success(resultURL))
        } catch {
            finish(with: .failure(.failedToMoveFileToDownloads))
        }
    }

}
