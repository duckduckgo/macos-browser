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
import os

final class FileDownloadManager {

    static let shared = FileDownloadManager()

    private init() { }

    private var subscriptions = Set<AnyCancellable>()
    private (set) var downloads = [FileDownloadTask]()

    @discardableResult
    func startDownload(_ download: FileDownload) -> FileDownloadTask {
        let state = download.downloadTask()

        state.start(localFileURLCallback: self.localFileURL(for: download)) { result in
            if case .success(let url) = result {
                // For now, show the file in Finder
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }

        }

        return state
    }

    private func localFileURL(for download: FileDownload) -> (FileDownloadTask, @escaping (URL?) -> Void) -> Void {
        { downloadTask, callback in

            let preferences = DownloadPreferences()
            guard download.shouldAlwaysPromptFileSaveLocation || preferences.alwaysRequestDownloadLocation else {
                let fileName = downloadTask.suggestedFilename ?? .uniqueFilename(for: downloadTask.fileTypes?.first)
                if let url = preferences.selectedDownloadLocation?.appendingPathComponent(fileName) {
                    callback(url)
                } else {
                    os_log("Failed to access Downloads folder")
                    Pixel.fire(.debug(event: .fileMoveToDownloadsFailed, error: CocoaError(.fileWriteUnknown)))
                    callback(nil)
                }
                return
            }

            let savePanel = NSSavePanel.withFileTypeChooser(fileTypes: downloadTask.fileTypes ?? [],
                                                            suggestedFilename: downloadTask.suggestedFilename,
                                                            directoryURL: preferences.selectedDownloadLocation)

            func completionHandler(_ result: NSApplication.ModalResponse) {
                guard case .OK = result, let url = savePanel.url else {
                    callback(nil)
                    return
                }
                if FileManager.default.fileExists(atPath: url.path) {
                    // overwrite
                    try? FileManager.default.removeItem(at: url)
                }

                callback(url)
            }

            if let window = download.window {
                savePanel.beginSheetModal(for: window, completionHandler: completionHandler)
            } else {
                completionHandler(savePanel.runModal())
            }
        }
    }

}
