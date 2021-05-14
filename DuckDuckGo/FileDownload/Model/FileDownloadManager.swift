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
    @Published private (set) var downloads = Set<FileDownloadTask>()

    typealias FileNameChooserCallback = (/*suggestedFilename:*/ String?,
                                         /*directoryURL:*/      URL?,
                                         /*fileTypes:*/         [UTType],
                                         /*completionHandler*/  @escaping (URL?, UTType?) -> Void) -> Void
    typealias FileIconOriginalRectCallback = (FileDownloadTask) -> NSRect?

    private var destinationChooserCallbacks = [FileDownloadTask: FileNameChooserCallback]()
    private var fileIconOriginalRectCallbacks = [FileDownloadTask: FileIconOriginalRectCallback]()

    @discardableResult
    func startDownload(_ request: FileDownload,
                       chooseDestinationCallback: @escaping FileNameChooserCallback,
                       fileIconOriginalRectCallback: FileIconOriginalRectCallback? = nil) -> FileDownloadTask {

        let task = request.downloadTask()
        self.destinationChooserCallbacks[task] = chooseDestinationCallback
        self.fileIconOriginalRectCallbacks[task] = fileIconOriginalRectCallback
        
        downloads.insert(task)
        task.start(delegate: self)

        return task
    }

}

extension FileDownloadManager: FileDownloadTaskDelegate {

    func fileDownloadTaskNeedsDestinationURL(_ task: FileDownloadTask, completionHandler: @escaping (URL?, UTType?) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))

        defer {
            self.destinationChooserCallbacks[task] = nil
            self.fileIconOriginalRectCallbacks[task] = nil
        }

        let completion: (URL?, UTType?) -> Void = { url, fileType in
            if let url = url,
               let originalRect = self.fileIconOriginalRectCallbacks[task]?(task) {
                task.progress.flyToImage = (UTType(fileExtension: url.pathExtension) ?? fileType)?.icon
                task.progress.fileIconOriginalRect = originalRect
            }

            completionHandler(url, fileType)
        }

        let preferences = DownloadPreferences()
        guard task.download.shouldAlwaysPromptFileSaveLocation || preferences.alwaysRequestDownloadLocation,
              let locationChooser = self.destinationChooserCallbacks[task]
        else {
            let fileType = task.fileTypes?.first
            let fileName = task.suggestedFilename ?? .uniqueFilename(for: fileType)
            if let url = preferences.selectedDownloadLocation?.appendingPathComponent(fileName) {
                completion(url, fileType)
            } else {
                os_log("Failed to access Downloads folder")
                Pixel.fire(.debug(event: .fileMoveToDownloadsFailed, error: CocoaError(.fileWriteUnknown)))
                completion(nil, nil)
            }
            return
        }

        locationChooser(task.suggestedFilename, preferences.selectedDownloadLocation, task.fileTypes ?? []) { url, fileType in
            if let url = url,
               FileManager.default.fileExists(atPath: url.path) {
                // overwrite
                try? FileManager.default.removeItem(at: url)
            }

            completion(url, fileType)
        }
    }

    func fileDownloadTask(_ task: FileDownloadTask, didFinishWith result: Result<URL, FileDownloadError>) {
        dispatchPrecondition(condition: .onQueue(.main))

        self.downloads.remove(task)
        self.destinationChooserCallbacks[task] = nil
        self.fileIconOriginalRectCallbacks[task] = nil

        if case .success(let url) = result {
            // For now, show the file in Finder
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

}
