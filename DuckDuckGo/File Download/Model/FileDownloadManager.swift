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

    private var downloadTaskDelegates = [WebKitDownloadTask: () -> FileDownloadManagerDelegate?]()

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

    // swiftlint:disable:next function_body_length
    func fileDownloadTaskNeedsDestinationURL(_ task: WebKitDownloadTask,
                                             suggestedFilename: String,
                                             completionHandler: @escaping (URL?, UTType?) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))

        let completion: (URL?, UTType?) -> Void = { url, fileType in
            if let url = url,
               let originalRect = self.downloadTaskDelegates[task]?()?.fileIconFlyAnimationOriginalRect(for: task) {
                task.progress.flyToImage = (UTType(fileExtension: url.pathExtension) ?? fileType)?.icon
                task.progress.fileIconOriginalRect = originalRect
            }

            completionHandler(url, fileType)

            self.downloadTaskDelegates[task] = nil
        }

        let downloadLocation = preferences.effectiveDownloadLocation
        let fileType = task.suggestedFileType

        guard task.shouldPromptForLocation || preferences.alwaysRequestDownloadLocation,
              let delegate = self.downloadTaskDelegates[task]?()
        else {
            // download to default Downloads destination
            var fileName = suggestedFilename
            if fileName.isEmpty {
                fileName = .uniqueFilename(for: fileType)
            }
            if let url = downloadLocation?.appendingPathComponent(fileName) {
                // Make sure the app has an access to destination
                let folderUrl = url.deletingLastPathComponent()
                guard self.verifyAccessToDestinationFolder(folderUrl,
                                                           destinationRequested: preferences.alwaysRequestDownloadLocation,
                                                           isSandboxed: NSApp.isSandboxed) else {
                    completion(nil, nil)
                    return
                }

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
        let fileTypes = fileType.map { [$0] } ?? []
        delegate.chooseDestination(suggestedFilename: suggestedFilename, directoryURL: downloadLocation, fileTypes: fileTypes) { [weak self] url, fileType in
            guard let self = self else {
                completion(nil, nil)
                return
            }

            if let url = url {
                // Make sure the app has an access to destination
                let folderUrl = url.deletingLastPathComponent()
                guard self.verifyAccessToDestinationFolder(folderUrl,
                                                           destinationRequested: self.preferences.alwaysRequestDownloadLocation,
                                                           isSandboxed: NSApp.isSandboxed) else {
                    completion(nil, nil)
                    return
                }

                self.preferences.lastUsedCustomDownloadLocation = folderUrl

                if FileManager.default.fileExists(atPath: url.path) {
                    // if SavePanel points to an existing location that means overwrite was chosen
                    try? FileManager.default.removeItem(at: url)
                }
            }

            completion(url, fileType)
        }
    }

    private func verifyAccessToDestinationFolder(_ folderUrl: URL, destinationRequested: Bool, isSandboxed: Bool) -> Bool {
        if destinationRequested && isSandboxed { return true }

        let folderPath = folderUrl.relativePath
        let c = open(folderPath, O_RDONLY)
        let hasAccess = c != -1
        close(c)

        if !hasAccess {
            askUserToGrantAccessToDestination(folderUrl)
        }

        return hasAccess
    }

    private func askUserToGrantAccessToDestination(_ folderUrl: URL) {
        if FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.lastPathComponent == folderUrl.lastPathComponent {
            let alert = NSAlert.noAccessToDownloads()
            if alert.runModal() != .cancel {
                guard let preferencesLink = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_DownloadsFolder") else {
                    assertionFailure("Can't initialize preferences link")
                    return
                }
                NSWorkspace.shared.open(preferencesLink)
                return
            }
        } else {
            let alert = NSAlert.noAccessToSelectedFolder()
            alert.runModal()
        }
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
