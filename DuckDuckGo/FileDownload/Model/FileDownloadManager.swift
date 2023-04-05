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

import AppKit
import Combine
import Navigation
import os

protocol FileDownloadManagerProtocol: AnyObject {
    var downloads: Set<WebKitDownloadTask> { get }
    var downloadsPublisher: AnyPublisher<WebKitDownloadTask, Never> { get }

    @discardableResult
    func add(_ download: WebKitDownload,
             fromDisposableWindow: Bool,
             delegate: DownloadTaskDelegate?,
             location: FileDownloadManager.DownloadLocationPreference) -> WebKitDownloadTask

    func cancelAll(waitUntilDone: Bool)
}

extension FileDownloadManagerProtocol {

    @discardableResult
    func add(_ download: WebKitDownload, fromDisposableWindow: Bool, location: FileDownloadManager.DownloadLocationPreference) -> WebKitDownloadTask {
        add(download, fromDisposableWindow: fromDisposableWindow, delegate: nil, location: location)
    }

}

protocol FileDownloadManagerDelegate: AnyObject {
    func askUserToGrantAccessToDestination(_ folderUrl: URL)
}

final class FileDownloadManager: FileDownloadManagerProtocol {

    static let shared = FileDownloadManager()
    private let preferences: DownloadsPreferences

    weak var delegate: FileDownloadManagerDelegate?

    init(preferences: DownloadsPreferences = .init()) {
        self.preferences = preferences
    }

    private (set) var downloads = Set<WebKitDownloadTask>()
    private var downloadAddedSubject = PassthroughSubject<WebKitDownloadTask, Never>()
    var downloadsPublisher: AnyPublisher<WebKitDownloadTask, Never> {
        downloadAddedSubject.eraseToAnyPublisher()
    }

    private var downloadTaskDelegates = [WebKitDownloadTask: () -> DownloadTaskDelegate?]()

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
    func add(_ download: WebKitDownload, fromDisposableWindow: Bool, delegate: DownloadTaskDelegate?, location: DownloadLocationPreference) -> WebKitDownloadTask {
        dispatchPrecondition(condition: .onQueue(.main))

        let task = WebKitDownloadTask(download: download,
                                      promptForLocation: location.promptForLocation,
                                      destinationURL: location.destinationURL,
                                      tempURL: location.tempURL,
                                      isDisposable: fromDisposableWindow)

        self.downloadTaskDelegates[task] = { [weak delegate] in delegate }

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

    // swiftlint:disable function_body_length
    func fileDownloadTaskNeedsDestinationURL(_ task: WebKitDownloadTask,
                                             suggestedFilename: String,
                                             completionHandler: @escaping (URL?, UTType?) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))

        let completion: (URL?, UTType?) -> Void = { url, fileType in
            defer {
                self.downloadTaskDelegates[task] = nil
            }

            guard let url = url else {
                completionHandler(nil, nil)
                return
            }

            if let originalRect = self.downloadTaskDelegates[task]?()?.fileIconFlyAnimationOriginalRect(for: task) {
                task.progress.flyToImage = (UTType(fileExtension: url.pathExtension) ?? fileType)?.icon
                task.progress.fileIconOriginalRect = originalRect
            }

            completionHandler(url, fileType)
        }

        let downloadLocation = preferences.effectiveDownloadLocation
        let fileType = task.suggestedFileType

        guard task.shouldPromptForLocation || preferences.alwaysRequestDownloadLocation,
              let delegate = self.downloadTaskDelegates[task]?()
        else {
            // download to default Downloads destination
            let fileName = suggestedFilename.isEmpty ? .uniqueFilename(for: fileType) : suggestedFilename

            guard let url = downloadLocation?.appendingPathComponent(fileName) else {
                os_log("Failed to access Downloads folder")
                Pixel.fire(.debug(event: .fileMoveToDownloadsFailed, error: CocoaError(.fileWriteUnknown)))
                completion(nil, nil)
                return
            }

            // Make sure the app has an access to destination
            let folderUrl = url.deletingLastPathComponent()
            guard self.verifyAccessToDestinationFolder(folderUrl,
                                                       destinationRequested: preferences.alwaysRequestDownloadLocation,
                                                       isSandboxed: NSApp.isSandboxed) else {
                completion(nil, nil)
                return
            }

            completion(url, fileType)
            return
        }

        var fileTypes = [UTType]()
        let fileExtension = (suggestedFilename as NSString).pathExtension
        // add file type from file extension first
        if !fileExtension.isEmpty,
           let utType = UTType(fileExtension: fileExtension),
           fileType != utType {

            fileTypes = [utType]
        }
        // append file type from mime
        if let fileType,
           fileType.fileExtension != nil || fileTypes.isEmpty {
            fileTypes.append(fileType)
        }

        delegate.chooseDestination(suggestedFilename: suggestedFilename, directoryURL: downloadLocation, fileTypes: fileTypes) { [weak self] url, fileType in
            guard let self, let url else {
                completion(nil, nil)
                return
            }

            let folderUrl = url.deletingLastPathComponent()
            self.preferences.lastUsedCustomDownloadLocation = folderUrl

            // Make sure the app has an access to destination
            guard self.verifyAccessToDestinationFolder(folderUrl,
                                                       destinationRequested: self.preferences.alwaysRequestDownloadLocation,
                                                       isSandboxed: NSApp.isSandboxed) else {
                completion(nil, nil)
                return
            }

            if FileManager.default.fileExists(atPath: url.path) {
                // if SavePanel points to an existing location that means overwrite was chosen
                try? FileManager.default.removeItem(at: url)
            }

            completion(url, fileType)
        }
    }
    // swiftlint:enable function_body_length
    // swiftlint:enable cyclomatic_complexity

    private func verifyAccessToDestinationFolder(_ folderUrl: URL, destinationRequested: Bool, isSandboxed: Bool) -> Bool {
        if destinationRequested && isSandboxed { return true }

        let folderPath = folderUrl.relativePath
        let c = open(folderPath, O_RDONLY)
        let hasAccess = c != -1
        close(c)

        if !hasAccess {
            delegate?.askUserToGrantAccessToDestination(folderUrl)
        }

        return hasAccess
    }

    func fileDownloadTask(_ task: WebKitDownloadTask, didFinishWith result: Result<URL, FileDownloadError>) {
        dispatchPrecondition(condition: .onQueue(.main))

        defer {
            self.downloads.remove(task)
            self.downloadTaskDelegates[task] = nil
        }

        if case .success(let url) = result {
            try? url.setQuarantineAttributes(sourceURL: task.originalRequest?.url,
                                             referrerURL: task.originalRequest?.mainDocumentURL)
        }
    }

}

protocol DownloadTaskDelegate: AnyObject {

    func chooseDestination(suggestedFilename: String?, directoryURL: URL?, fileTypes: [UTType], callback: @escaping (URL?, UTType?) -> Void)
    func fileIconFlyAnimationOriginalRect(for downloadTask: WebKitDownloadTask) -> NSRect?

}
