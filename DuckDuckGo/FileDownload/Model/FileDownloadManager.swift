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
    private let workspace: NSWorkspace
    private let preferences: DownloadPreferences

    init(workspace: NSWorkspace = .shared, preferences: DownloadPreferences = .init()) {
        self.workspace = workspace
        self.preferences = preferences
    }

    @PublishedAfter private (set) var downloads = Set<FileDownloadTask>()

    typealias FileNameChooserCallback = (/*suggestedFilename:*/ String?,
                                         /*directoryURL:*/      URL?,
                                         /*fileTypes:*/         [UTType],
                                         /*completionHandler*/  @escaping (URL?, UTType?) -> Void) -> Void
    typealias FileIconOriginalRectCallback = (FileDownloadTask) -> NSRect?

    private var destinationChooserCallbacks = [FileDownloadTask: FileNameChooserCallback]()
    private var fileIconOriginalRectCallbacks = [FileDownloadTask: FileIconOriginalRectCallback]()

    @discardableResult
    func startDownload(_ request: FileDownloadRequest,
                       chooseDestinationCallback: FileNameChooserCallback? = nil,
                       fileIconOriginalRectCallback: FileIconOriginalRectCallback? = nil,
                       postflight: FileDownloadPostflight?) -> FileDownloadTask? {

        guard let task = request.downloadTask() else { return nil }

        self.destinationChooserCallbacks[task] = chooseDestinationCallback
        self.fileIconOriginalRectCallbacks[task] = fileIconOriginalRectCallback
        task.postflight = postflight

        downloads.insert(task)
        task.start(delegate: self)

        return task
    }

}

extension FileDownloadManager: FileDownloadTaskDelegate {

    func fileDownloadTaskNeedsDestinationURL(_ task: FileDownloadTask, completionHandler: @escaping (URL?, UTType?) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))

        let completion: (URL?, UTType?) -> Void = { url, fileType in
            if let url = url,
               let originalRect = self.fileIconOriginalRectCallbacks[task]?(task) {
                task.progress.flyToImage = (UTType(fileExtension: url.pathExtension) ?? fileType)?.icon
                task.progress.fileIconOriginalRect = originalRect
            }

            completionHandler(url, fileType)
            
            self.destinationChooserCallbacks[task] = nil
            self.fileIconOriginalRectCallbacks[task] = nil
        }

        guard task.download.shouldAlwaysPromptFileSaveLocation || preferences.alwaysRequestDownloadLocation,
              let locationChooser = self.destinationChooserCallbacks[task]
        else {
            let fileType = task.fileTypes?.first
            var fileName = task.suggestedFilename
            if fileName.isEmpty {
                fileName = .uniqueFilename(for: fileType)
            }
            if let url = preferences.selectedDownloadLocation?.appendingPathComponent(fileName) {
                completion(url, fileType)
            } else {
                os_log("Failed to access Downloads folder")
                Pixel.fire(.debug(event: .fileMoveToDownloadsFailed, error: CocoaError(.fileWriteUnknown)))
                completion(nil, nil)
            }
            return
        }

        // drop known extension, it would be appended by SavePanel
        let suggestedFilename = task.fileTypes.flatMap(\.first?.fileExtension).map { task.suggestedFilename.drop(suffix: "." + $0) }
        locationChooser(suggestedFilename, preferences.selectedDownloadLocation, task.fileTypes ?? []) { url, fileType in
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

        defer {
            self.downloads.remove(task)
            self.destinationChooserCallbacks[task] = nil
            self.fileIconOriginalRectCallbacks[task] = nil
        }

        if case .success(let url) = result {
            switch task.postflight {
            case .open:
                self.workspace.open(url)
            case .reveal:
                self.workspace.activateFileViewerSelecting([url])
            case .none:
                break
            }
        }
    }

}

protocol FileDownloadManagerDelegate: AnyObject {

    func chooseDestination(suggestedFilename: String?, directoryURL: URL?, fileTypes: [UTType], callback: @escaping (URL?, UTType?) -> Void)
    func fileIconFlyAnimationOriginalRect(for downloadTask: FileDownloadTask) -> NSRect?

}

extension FileDownloadManager {

    @discardableResult
    func startDownload(_ request: FileDownloadRequest,
                       delegate: FileDownloadManagerDelegate?,
                       postflight: FileDownloadPostflight?) -> FileDownloadTask? {
        return self.startDownload(request,
                                  chooseDestinationCallback: delegate?.chooseDestination,
                                  fileIconOriginalRectCallback: delegate?.fileIconFlyAnimationOriginalRect,
                                  postflight: postflight)
    }

}
