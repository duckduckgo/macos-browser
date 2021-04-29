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
    let fileTypes: [UTType]?

    var suggestedFilename: String? {
        url.lastPathComponent
    }

    init(url: URL, fileType: UTType?) {
        self.url = url
        self.fileTypes = fileType.map { [$0] }
    }

    func start(localFileURLCallback: @escaping LocalFileURLCallback, completion: @escaping (Result<URL, FileDownloadError>) -> Void) {
        localFileURLCallback(self) { url in
            guard let destURL = url else {
                completion(.failure(.cancelled))
                return
            }

            do {
                let resultURL = try FileManager.default.copyItem(at: self.url, to: destURL, incrementingIndexIfExists: true)
                completion(.success(resultURL))
            } catch {
                completion(.failure(.failedToMoveFileToDownloads))
            }
        }
    }

}
