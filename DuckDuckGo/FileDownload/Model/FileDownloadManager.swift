//
//  FileDownloadManager.swift
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

import Cocoa
import Combine

final class FileDownloadManager {

    static let shared = FileDownloadManager()

    private init() { }

    private var subscriptions = Set<AnyCancellable>()
    private (set) var downloads = Set<FileDownloadTask>()

    @discardableResult
    func startDownload(_ download: FileDownload) -> FileDownloadTask {
        let state = FileDownloadTask(download: download)

        state.$filePath.receive(on: DispatchQueue.main).compactMap { $0 }.sink { filePath in

            let file = URL(fileURLWithPath: filePath)

            // For now, show the file in Finder
            NSWorkspace.shared.activateFileViewerSelecting([file])

        }.store(in: &subscriptions)

        state.start()

        return state
    }

    func saveDataToFile(_ data: Data, withSuggestedFileName suggestedFile: String, mimeType: String) {

        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        guard fm.createFile(atPath: temp.path, contents: data, attributes: nil) else { return }

        if let path = temp.moveToDownloadsFolder(withFileName: suggestedFile) {
            let file = URL(fileURLWithPath: path)
            NSWorkspace.shared.activateFileViewerSelecting([file])
        }

    }

}
