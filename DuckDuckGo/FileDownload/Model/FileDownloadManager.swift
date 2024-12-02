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
import Common
import Navigation
import UniformTypeIdentifiers
import os.log

protocol FileDownloadManagerProtocol: AnyObject {
    var downloads: Set<WebKitDownloadTask> { get }
    var downloadsPublisher: AnyPublisher<WebKitDownloadTask, Never> { get }

    @discardableResult
    @MainActor
    func add(_ download: WebKitDownload, fireWindowSession: FireWindowSessionRef?, delegate: DownloadTaskDelegate?, destination: WebKitDownloadTask.DownloadDestination) -> WebKitDownloadTask

    func cancelAll(waitUntilDone: Bool)
}

extension FileDownloadManagerProtocol {

    @discardableResult
    @MainActor
    func add(_ download: WebKitDownload, fireWindowSession: FireWindowSessionRef?, destination: WebKitDownloadTask.DownloadDestination) -> WebKitDownloadTask {
        add(download, fireWindowSession: fireWindowSession, delegate: nil, destination: destination)
    }

}

final class FileDownloadManager: FileDownloadManagerProtocol {

    static let shared = FileDownloadManager()
    private let preferences: DownloadsPreferences

    init(preferences: DownloadsPreferences = .shared) {
        self.preferences = preferences
    }

    private(set) var downloads = Set<WebKitDownloadTask>()
    private var downloadAddedSubject = PassthroughSubject<WebKitDownloadTask, Never>()
    var downloadsPublisher: AnyPublisher<WebKitDownloadTask, Never> {
        downloadAddedSubject.eraseToAnyPublisher()
    }

    private var downloadTaskDelegates = [WebKitDownloadTask: () -> DownloadTaskDelegate?]()

    @discardableResult
    @MainActor
    func add(_ download: WebKitDownload, fireWindowSession: FireWindowSessionRef?, delegate: DownloadTaskDelegate?, destination: WebKitDownloadTask.DownloadDestination) -> WebKitDownloadTask {
        dispatchPrecondition(condition: .onQueue(.main))

        var destination = destination
        // always prompt when "downloading" a local file
        if download.originalRequest?.url?.isFileURL ?? true, case .auto = destination {
            destination = .prompt
        }
        let task = WebKitDownloadTask(download: download, destination: destination, fireWindowSession: fireWindowSession)
        Logger.fileDownload.debug("add \(String(describing: download)): \(download.originalRequest?.url?.absoluteString ?? "<nil>") -> \(destination.debugDescription): \(task)")

        let shouldCancelDownloadIfDelegateIsGone = delegate != nil
        self.downloadTaskDelegates[task] = { [weak delegate] in
            if let delegate {
                return delegate
            }
            // if the delegate was originally provided but deallocated since then – the download task should be cancelled
            if shouldCancelDownloadIfDelegateIsGone {
                Logger.fileDownload.debug("🦀 \( String(describing: download) ) delegate is gone: cancelling")
                return CancelledDownloadTaskDelegate()
            }
            return nil
        }

        downloads.insert(task)
        downloadAddedSubject.send(task)
        task.start(delegate: self)

        return task
    }

    func cancelAll(waitUntilDone: Bool) {
        dispatchPrecondition(condition: .onQueue(.main))

        Logger.fileDownload.debug("FileDownloadManager: cancel all: [\(self.downloads.map(\.debugDescription).joined(separator: ", "))]")
        let dispatchGroup: DispatchGroup? = waitUntilDone ? DispatchGroup() : nil
        var cancellables = Set<AnyCancellable>()
        for task in downloads {
            if waitUntilDone {
                dispatchGroup?.enter()
                task.$state.sink { state in
                    if state.isCompleted {
                        dispatchGroup?.leave()
                    }
                }
                .store(in: &cancellables)
            }

            task.cancel()
        }
        if let dispatchGroup {
            withExtendedLifetime(cancellables) {
                RunLoop.main.run(until: RunLoop.ResumeCondition(dispatchGroup: dispatchGroup))
            }
        }
    }

}

extension FileDownloadManager: WebKitDownloadTaskDelegate {

    @MainActor
    func fileDownloadTaskNeedsDestinationURL(_ task: WebKitDownloadTask, suggestedFilename: String, suggestedFileType fileType: UTType?) async -> (URL?, UTType?) {
        guard case (.some(let url), let fileType) = await chooseDestination(for: task, suggestedFilename: suggestedFilename, suggestedFileType: fileType) else {
            Logger.fileDownload.debug("choose destination cancelled: \(task)")
            return (nil, nil)
        }
        Logger.fileDownload.debug("destination chosen: \(task): \"\(url.path)\" (\(fileType?.description ?? "nil"))")

        if let originalRect = self.downloadTaskDelegates[task]?()?.fileIconFlyAnimationOriginalRect(for: task) {
            let utType = UTType(filenameExtension: url.pathExtension) ?? fileType ?? .data
            task.progress.flyToImage = NSWorkspace.shared.icon(for: utType)
            task.progress.fileIcon = task.progress.flyToImage
            task.progress.fileIconOriginalRect = originalRect
        }

        self.downloadTaskDelegates[task] = nil
        return (url, fileType)
    }

    @MainActor
    private func chooseDestination(for task: WebKitDownloadTask, suggestedFilename: String, suggestedFileType fileType: UTType?) async -> (URL?, UTType?) {
        guard task.shouldPromptForLocation || preferences.alwaysRequestDownloadLocation,
              self.downloadTaskDelegates[task]?() != nil else {
            return await defaultDownloadLocation(for: task, suggestedFilename: suggestedFilename, fileType: fileType)
        }

        return await requestDestinationFromUser(for: task, suggestedFilename: suggestedFilename, suggestedFileType: fileType)
    }

    @MainActor
    private func requestDestinationFromUser(for task: WebKitDownloadTask, suggestedFilename: String, suggestedFileType fileType: UTType?) async -> (URL?, UTType?) {
        return await withCheckedContinuation { continuation in
            requestDestinationFromUser(for: task, suggestedFilename: suggestedFilename, suggestedFileType: fileType) { (url, fileType) in
                continuation.resume(returning: (url, fileType))
            }
        }
    }

    @MainActor
    private func requestDestinationFromUser(for task: WebKitDownloadTask, suggestedFilename: String, suggestedFileType fileType: UTType?, completionHandler: @escaping (URL?, UTType?) -> Void) {
        // !!!
        // don‘t refactor this to `async` style as it will make the `delegate` retained for the scope of the async func
        // leading to a retain cycle when a background Tab presenting Save Dialog is closed
        guard let delegate = self.downloadTaskDelegates[task]?() else {
            completionHandler(nil, nil)
            return
        }

        var fileTypes = [UTType]()
        let fileExtension = suggestedFilename.pathExtension
        // add file type from file extension first
        if !fileExtension.isEmpty,
           let utType = UTType(filenameExtension: fileExtension),
           fileType != utType {

            fileTypes = [utType]
        }
        // append file type from mime
        if let fileType,
           fileType.preferredFilenameExtension != nil || fileTypes.isEmpty {
            fileTypes.append(fileType)
        }

        Logger.fileDownload.debug("FileDownloadManager: requesting download location \"\(suggestedFilename)\"/\(fileTypes.map(\.description).joined(separator: ", "))")
        delegate.chooseDestination(suggestedFilename: suggestedFilename, fileTypes: fileTypes) { url, fileType in
            guard let url else {
                completionHandler(nil, nil)
                return
            }

            let folderUrl = url.deletingLastPathComponent()
            self.preferences.lastUsedCustomDownloadLocation = folderUrl

            // we shouldn‘t validate directory access here as we won‘t have it in sandboxed builds - only to the destination URL
            completionHandler(url, fileType)
        }
    }

    @MainActor
    private func defaultDownloadLocation(for task: WebKitDownloadTask, suggestedFilename: String, fileType: UTType?) async -> (URL?, UTType?) {
        // download to default Downloads destination
        guard let downloadLocation = preferences.effectiveDownloadLocation ?? DownloadsPreferences.defaultDownloadLocation(validate: false /* verify later */) else {
            pixelAssertionFailure("Failed to access Downloads folder")
            return (nil, nil)
        }

        let fileName = suggestedFilename.isEmpty ? "download".appendingPathExtension(fileType?.preferredFilenameExtension) : suggestedFilename
        var url = downloadLocation.appendingPathComponent(fileName)
        Logger.fileDownload.debug("FileDownloadManager: using default download location for \"\(suggestedFilename)\": \"\(url.path)\"")

        // make sure the app has access to the destination
        let folderUrl = url.deletingLastPathComponent()
        let fm = FileManager.default
        guard fm.isWritableFile(atPath: folderUrl.path) else {
            Logger.fileDownload.debug("FileDownloadManager: no write permissions for \"\(folderUrl.path)\": fallback to user request")
            return await requestDestinationFromUser(for: task, suggestedFilename: suggestedFilename, suggestedFileType: fileType)
        }

        // choose non-existent filename
        do {
            url = try fm.withNonExistentUrl(for: url, incrementingIndexIfExistsUpTo: 10000) { url in
                // the file will be overwritten in the WebKitDownloadTask
                try fm.createFile(atPath: url.path, contents: nil) ? url : { throw CocoaError(.fileWriteFileExists) }()
            }
        } catch {
            pixelAssertionFailure("Failed to create file in the Downloads folder")
            return (nil, nil)
        }

        return (url, fileType)
    }

    func fileDownloadTask(_ task: WebKitDownloadTask, didFinishWith result: Result<Void, FileDownloadError>) {
        dispatchPrecondition(condition: .onQueue(.main))

        self.downloads.remove(task)
        self.downloadTaskDelegates[task] = nil

        Logger.fileDownload.debug("❎ removed task \(task)")
    }

}

extension FileDownloadManager {

    static func observeDownloadsFinished(_ downloads: Set<WebKitDownloadTask>, callback: @escaping () -> Void) -> AnyCancellable {
        var cancellables = [WebKitDownloadTask: AnyCancellable]()
        for download in downloads {
            cancellables[download] = download.$state.sink {
                if !$0.isDownloading {
                    cancellables[download] = nil
                    if cancellables.isEmpty {
                        callback()
                    }
                }
            }
        }
        return AnyCancellable {
            cancellables.removeAll()
        }
    }

}

protocol DownloadTaskDelegate: AnyObject {

    @MainActor
    func chooseDestination(suggestedFilename: String?, fileTypes: [UTType], callback: @escaping @MainActor (URL?, UTType?) -> Void)
    @MainActor
    func fileIconFlyAnimationOriginalRect(for downloadTask: WebKitDownloadTask) -> NSRect?

}

// if the original Download Task delegate is gone, this one is used to cancel the download
final class CancelledDownloadTaskDelegate: DownloadTaskDelegate {

    func chooseDestination(suggestedFilename: String?, fileTypes: [UTType], callback: @escaping @MainActor (URL?, UTType?) -> Void) {
        callback(nil, nil)
    }

    func fileIconFlyAnimationOriginalRect(for downloadTask: WebKitDownloadTask) -> NSRect? {
        nil
    }

}

extension WebKitDownloadTask.DownloadDestination: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case .auto:
            ".auto"
        case .prompt:
            ".prompt"
        case .preset(let destinationURL):
            ".preset(destinationURL: \"\(destinationURL.path)\")"
        case .resume(destination: let destination, tempFile: let tempFile):
            ".resume(destination: \"\(destination.url?.path ?? "<nil>")\", tempFile: \"\(tempFile.url?.path ?? "<nil>")\")"
        }
    }
}
