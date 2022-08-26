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

protocol FileDownloadManagerProtocol: AnyObject {
    var downloads: Set<WebKitDownloadTask> { get }
    var downloadsPublisher: AnyPublisher<WebKitDownloadTask, Never> { get }

    @discardableResult
    func add(_ download: WebKitDownload,
             delegate: FileDownloadManagerDelegate?,
             location: FileDownloadManager.DownloadLocationPreference,
             postflight: FileDownloadManager.PostflightAction?) -> WebKitDownloadTask

    func cancelAll(waitUntilDone: Bool)
}

final class FileDownloadManager: FileDownloadManagerProtocol {

    static let shared = FileDownloadManager()
    private let workspace: NSWorkspace
    private let preferences: DownloadsPreferences

    init(workspace: NSWorkspace = NSWorkspace.shared,
         preferences: DownloadsPreferences = .init()) {
        self.workspace = workspace
        self.preferences = preferences
    }

    private (set) var downloads = Set<WebKitDownloadTask>()
    private var downloadAddedSubject = PassthroughSubject<WebKitDownloadTask, Never>()
    var downloadsPublisher: AnyPublisher<WebKitDownloadTask, Never> {
        downloadAddedSubject.eraseToAnyPublisher()
    }

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

    enum DownloadLocationPreference: Equatable {
        case auto
        case prompt
        case preset(destinationURL: URL, tempURL: URL?)

        var destinationURL: URL? {
            guard case .preset(destinationURL: let url, tempURL: _) = self else { return nil }
            return url
        }

        var tempURL: URL? {
            guard case .preset(destinationURL: _, tempURL: let url) = self else { return nil }
            return url
        }

        var promptForLocation: Bool {
            switch self {
            case .prompt: return true
            case .preset, .auto: return false
            }
        }
    }

    @discardableResult
    func add(_ download: WebKitDownload,
             delegate: FileDownloadManagerDelegate?,
             location: DownloadLocationPreference,
             postflight: PostflightAction?) -> WebKitDownloadTask {
        dispatchPrecondition(condition: .onQueue(.main))

        let task = WebKitDownloadTask(download: download,
                                      promptForLocation: location.promptForLocation,
                                      destinationURL: location.destinationURL,
                                      tempURL: location.tempURL,
                                      postflight: postflight)

        self.destinationChooserCallbacks[task] = delegate?.chooseDestination
        self.fileIconOriginalRectCallbacks[task] = delegate?.fileIconFlyAnimationOriginalRect

        downloads.insert(task)
        downloadAddedSubject.send(task)
        task.start(delegate: self)

        return task
    }

    func cancelAll(waitUntilDone: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))

        let dispatchGroup: DispatchGroup? = waitUntilDone ? DispatchGroup() : nil
        var cancellables = Set<AnyCancellable>()
        for task in downloads {
            if waitUntilDone {
                dispatchGroup?.enter()
                task.output.sink { _ in
                    dispatchGroup?.leave()
                } receiveValue: { _ in }
                .store(in: &cancellables)
            }

            task.cancel()
        }
        if let dispatchGroup = dispatchGroup {
            RunLoop.main.run(until: RunLoop.ResumeCondition(dispatchGroup: dispatchGroup))
        }
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

        let downloadLocation = preferences.effectiveDownloadLocation
        let fileType = task.suggestedFileType

        guard task.shouldPromptForLocation || preferences.alwaysRequestDownloadLocation,
              let locationChooser = self.destinationChooserCallbacks[task]
        else {
            // download to default Downloads destination
            var fileName = suggestedFilename
            if fileName.isEmpty {
                fileName = .uniqueFilename(for: fileType)
            }
            if let url = downloadLocation?.appendingPathComponent(fileName) {
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
            suggestedFilename = suggestedFilename.dropping(suffix: "." + ext)
        }

        locationChooser(suggestedFilename, downloadLocation, fileType.map { [$0] } ?? []) { url, fileType in
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
            try? url.setQuarantineAttributes(sourceURL: task.originalRequest?.url,
                                             referrerURL: task.originalRequest?.mainDocumentURL)

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
