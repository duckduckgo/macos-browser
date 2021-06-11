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

    @PublishedAfter private (set) var downloads = Set<WebKitDownloadTask>()

    typealias FileNameChooserCallback = (/*suggestedFilename:*/ String?,
                                         /*directoryURL:*/      URL?,
                                         /*fileTypes:*/         [UTType],
                                         /*completionHandler*/  @escaping (URL?, UTType?) -> Void) -> Void
    typealias FileIconOriginalRectCallback = (WebKitDownloadTask) -> NSRect?

    private var destinationChooserCallbacks = [WebKitDownloadTask: FileNameChooserCallback]()
    private var fileIconOriginalRectCallbacks = [WebKitDownloadTask: FileIconOriginalRectCallback]()

    enum PostflightAction {
        case reveal
        case open
    }

    @discardableResult
    func add(_ download: WebKitDownload,
             delegate: FileDownloadManagerDelegate?,
             promptForLocation: Bool,
             postflight: PostflightAction?) -> WebKitDownloadTask {

        let task = WebKitDownloadTask(download: download,
                                      promptForLocation: promptForLocation,
                                      postflight: postflight)

        self.destinationChooserCallbacks[task] = delegate?.chooseDestination
        self.fileIconOriginalRectCallbacks[task] = delegate?.fileIconFlyAnimationOriginalRect

        downloads.insert(task)
        task.start(delegate: self)

        return task
    }

}

extension FileDownloadManager: WebKitDownloadTaskDelegate {

    func fileDownloadTaskNeedsDestinationURL(_ task: WebKitDownloadTask,
                                             suggestedFilename: String,
                                             completionHandler: @escaping (URL?, UTType?) -> Void) {
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

        let selectedDownloadLocation = preferences.selectedDownloadLocation
        let fileType = task.fileType

        guard task.shouldPromptForLocation || preferences.alwaysRequestDownloadLocation,
              let locationChooser = self.destinationChooserCallbacks[task]
        else {
            // download to default Downloads destination
            var fileName = suggestedFilename
            if fileName.isEmpty {
                fileName = .uniqueFilename(for: fileType)
            }
            if let url = selectedDownloadLocation?.appendingPathComponent(fileName) {
                completion(url, fileType)
            } else {
                os_log("Failed to access Downloads folder")
                Pixel.fire(.debug(event: .fileMoveToDownloadsFailed, error: CocoaError(.fileWriteUnknown)))
                completion(nil, nil)
            }
            return
        }

        // drop known extension, it would be appended by SavePanel
        var suggestedFilename = suggestedFilename
        if let ext = fileType?.fileExtension {
            suggestedFilename = suggestedFilename.drop(suffix: "." + ext)
        }

        locationChooser(suggestedFilename, selectedDownloadLocation, fileType.map { [$0] } ?? []) { url, fileType in
            if let url = url,
               FileManager.default.fileExists(atPath: url.path) {
                // if SavePanel points to an existing location that means overwrite was chosen
                try? FileManager.default.removeItem(at: url)
            }

            completion(url, fileType)
        }
    }

    func fileDownloadTask(_ task: WebKitDownloadTask, didFinishWith result: Result<URL, FileDownloadError>) {
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
    func fileIconFlyAnimationOriginalRect(for downloadTask: WebKitDownloadTask) -> NSRect?

}
