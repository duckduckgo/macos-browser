//
//  WebKitDownloadTask.swift
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
import Combine
import BrowserServicesKit
import Common
import Navigation
import UniformTypeIdentifiers
import WebKit
import PixelKit
import os.log

protocol WebKitDownloadTaskDelegate: AnyObject {
    func fileDownloadTaskNeedsDestinationURL(_ task: WebKitDownloadTask, suggestedFilename: String, suggestedFileType: UTType?) async -> (URL?, UTType?)
    func fileDownloadTask(_ task: WebKitDownloadTask, didFinishWith result: Result<Void, FileDownloadError>)
}

/// WKDownload wrapper managing Finder File Progress and coordinating file URLs
final class WebKitDownloadTask: NSObject, ProgressReporting, @unchecked Sendable {

    static let downloadExtension = "duckload"

    enum DownloadDestination {
        /// download destination would be requested from user or selected automatically depending on the “always prompt where to save files” setting
        case auto
        /// override “always prompt where to save files” for this download and prompt user for location
        case prompt
        /// desired destination URL provided when adding the download (like a temporary URL for PDF printing)
        case preset(URL)
        /// download is resumed to existing destination placeholder and `.duckload` file
        case resume(destination: FilePresenter, tempFile: FilePresenter)
    }
    enum FileDownloadState {
        case initial(DownloadDestination)
        /// - Parameter destination: final destination file placeholder file presenter
        /// - Parameter tempFile: Temporary  (.duckload)  file presenter
        case downloading(destination: FilePresenter, tempFile: FilePresenter)
        /// file presenter used to track the downloaded file across file system
        case downloaded(FilePresenter)
        /// `destination` and `tempFile` can be used along with `resumeData` to restart a failed download (if `error.isRetryable` is `true`)
        case failed(destination: FilePresenter?, tempFile: FilePresenter?, resumeData: Data?, error: FileDownloadError /* error type is force-casted in the code below in mapError (twice)! */)

        var isInitial: Bool {
            if case .initial = self { true } else { false }
        }

        var isDownloading: Bool {
            if case .downloading = self { true } else { false }
        }

        var destinationFilePresenter: FilePresenter? {
            switch self {
            case .initial(.resume(destination: let destinationFile, _)): return destinationFile
            case .initial: return nil
            case .downloading(destination: let destinationFile, _): return destinationFile
            case .downloaded(let destinationFile): return destinationFile
            case .failed(destination: let destinationFile, _, resumeData: _, _): return destinationFile
            }
        }

        var tempFilePresenter: FilePresenter? {
            switch self {
            case .initial(.resume(_, tempFile: let tempFile)): return tempFile
            case .initial: return nil
            case .downloading(_, tempFile: let tempFile): return tempFile
            case .downloaded: return nil
            case .failed(_, tempFile: let tempFile, _, _): return tempFile
            }
        }

        var isCompleted: Bool {
            switch self {
            case .initial: false
            case .downloading: false
            case .downloaded: true
            case .failed: true
            }
        }
    }

    @Published @MainActor private(set) var state: FileDownloadState {
        didSet {
            subscribeToTempFileURL(state.tempFilePresenter)
        }
    }

    /// downloads initiated from a Burner Window will be kept in the window
    let fireWindowSession: FireWindowSessionRef?

    private weak var delegate: WebKitDownloadTaskDelegate?

    private var download: WebKitDownload!
    /// used to report the download progress, byte count and estimated time
    let progress: Progress
    /// used to report file progress in Finder and Dock
    private var fileProgressPresenter: FileProgressPresenter?
#if DEBUG
    var fileProgress: Progress? { fileProgressPresenter?.fileProgress }
#endif

    /// temp directory for the downloaded item (removed after completion)
    @MainActor private var itemReplacementDirectory: URL?
    @MainActor private var itemReplacementDirectoryFSOCancellable: AnyCancellable?
    @MainActor private var tempFileUrlCancellable: AnyCancellable?
    @MainActor private(set) var selectedDestinationURL: URL?

    var originalRequest: URLRequest? {
        download.originalRequest
    }
    var originalWebView: WKWebView? {
        download.webView
    }
    @MainActor var shouldPromptForLocation: Bool {
        return if case .initial(.prompt) = state { true } else { false }
    }

    @MainActor(unsafe)
    init(download: WebKitDownload, destination: DownloadDestination, fireWindowSession: FireWindowSessionRef?) {
        self.download = download
        self.progress = DownloadProgress(download: download)
        self.fileProgressPresenter = FileProgressPresenter(progress: progress)
        self.state = .initial(destination)
        self.fireWindowSession = fireWindowSession
        super.init()

        progress.cancellationHandler = { [weak self, taskDescr=self.debugDescription] in
            Logger.fileDownload.debug("❌ progress.cancellationHandler \(taskDescr)")
            self?.cancel()
        }
    }

    /// called by the FileDownloadManager after adding the Download Task
    ///
    /// 1. sets `WKDownload` delegate to approve&start the download
    /// 2. `WKDownload` (a new one) calls `…decideDestinationUsingResponse:…`
    ///     - resumed downloads use pre-provided destination and temp file
    /// 3. after destination is chosen we create a placeholder file at the final destination URL (and set a File Presenter to track its renaming/removal)
    ///   but start the download into a temporary directory (`itemReplacementDirectory`) observing its contents.
    /// 4. when the download is started, we detect a file being created in the temporary directory and move it to the final destination folder
    ///   replacing its original file extension with `.duckload` – this file would be used to track user-facing progress in Finder/Dock
    /// 5. after the download is finished we merge the two files by replacing the final destination file with the `.duckload` file
    ///
    /// - if the temporary file is renamed, we try to rename the destination file accordingly (this would fail in sandboxed builds for non-preset directories)
    /// - if any of the two files is removed, the download is cancelled
    @MainActor func start(delegate: WebKitDownloadTaskDelegate) {
        Logger.fileDownload.debug("🟢 start \(self)")

        self.delegate = delegate

        // if resuming download – file presenters are provided as init parameter
        // when the resumed download is started using `WKWebView.resumeDownload`,
        // `decideDestination` callback wouldn‘t be called.
        // if the download is “resumed” as a new download (replacing the destination file) -
        // the presenters will be used in the `decideDestination` callback
        if case .initial(.resume(destination: let destination, tempFile: let tempFile)) = state {
            state = .downloading(destination: destination, tempFile: tempFile)
        }
        // otherwise, setting `download.delegate` initiates `decideDestination` callback
        // that will call `localFileURLCompletionHandler`
        download.delegate = self
    }

    @MainActor func subscribeToTempFileURL(_ tempFilePresenter: FilePresenter?) {
        tempFileUrlCancellable = (tempFilePresenter?.urlPublisher ?? Just(nil).eraseToAnyPublisher())
            .sink { [weak self] url in
                Task { [weak self] in
                    await self?.tempFileUrlUpdated(to: url)
                }
            }
    }

    /// Observe `.duckload` file moving and renaming, update the file progress and rename destination file if needed
    private nonisolated func tempFileUrlUpdated(to url: URL?) async {
        let (state, itemReplacementDirectory) = await MainActor.run {
            // display file progress and fly-to-dock animation
            // don‘t display progress in itemReplacementDirectory
            if let url, self.itemReplacementDirectory == nil || !url.path.hasPrefix(self.itemReplacementDirectory!.path) {
                self.fileProgressPresenter?.displayFileProgress(at: url)
            } else {
                self.fileProgressPresenter?.displayFileProgress(at: nil)
            }

            return (self.state, self.itemReplacementDirectory)
        }

        /// if user has renamed the `.duckload` file - also rename the destination file
        guard let destinationFilePresenter = state.destinationFilePresenter,
              let destinationURL = destinationFilePresenter.url,
              let newDestinationURL = state.tempFilePresenter?.url.flatMap({ tempFileURL -> URL? in
                  guard itemReplacementDirectory == nil || !tempFileURL.path.hasPrefix(itemReplacementDirectory!.path) else { return nil }

                  // drop `duckload` file extension (if it‘s still there) and append the original one
                  let newFileName = tempFileURL.lastPathComponent.dropping(suffix: "." + Self.downloadExtension).appendingPathExtension(destinationURL.pathExtension)
                  return destinationURL.deletingLastPathComponent().appendingPathComponent(newFileName)
              }),
              destinationURL != newDestinationURL else { try? await Task.sleep(interval: 1); return }

        do {
            Logger.fileDownload.debug("renaming destination file \"\(destinationURL.path)\" ➡️ \"\(destinationURL.path)\"")
            try destinationFilePresenter.coordinateMove(to: newDestinationURL, with: []) { from, to in
                try FileManager.default.moveItem(at: from, to: to)
                destinationFilePresenter.presentedItemDidMove(to: newDestinationURL) // coordinated File Presenter won‘t receive URL updates
            }
        } catch {
            Logger.fileDownload.debug("renaming file failed: \(error)")
        }
    }

    /// called at `WKDownload`s `decideDestination` completion callback with selected URL (or `nil` if cancelled)
    private enum DestinationCleanupStyle { case remove, clear }
    private nonisolated func prepareChosenDestinationURL(_ destinationURL: URL?, fileType _: UTType?, cleanupStyle: DestinationCleanupStyle) async -> URL? {
        do {
            let fm = FileManager()
            guard let destinationURL else { throw URLError(.cancelled) }
            // in case we‘re overwriting the URL – increment the access counter for the duration of the method
            let accessStarted = destinationURL.startAccessingSecurityScopedResource()
            defer {
                if accessStarted {
                    destinationURL.stopAccessingSecurityScopedResource()
                }
            }
            Logger.fileDownload.debug("download task callback: creating temp directory for \"\(destinationURL.path)\"")

            switch cleanupStyle {
            case .remove:
                // 1. remove the destination file if exists – that would clear existing downloads file presenters and stop downloads accordingly (if any)
                try NSFileCoordinator().coordinateWrite(at: destinationURL, with: .forDeleting) { url in
                    if !fm.fileExists(atPath: url.path) {
                        // validate we can write to the directory even if there‘s no existing file
                        try Data().write(to: destinationURL)
                    }
                    Logger.fileDownload.debug("🧹 removing \"\(url.path)\"")
                    try fm.removeItem(at: url)
                }
            case .clear:
                // 2. the download is “resumed” to existing destinationURL – clear it.
                try Data().write(to: destinationURL)
            }

            // 2. start downloading to a newly created same-volume temporary directory
            let tempURL = try await setupTemporaryDownloadURL(for: destinationURL, fileAddedHandler: { [weak self] tempURL in
                // keep the cancellable ref until File Presenters instantiation is finished
                // - in case we receive an early `downloadDidFail:`
                self?.itemReplacementDirectoryFSOCancellable?.cancel()

                // then move the file to the final destination
                Task { [weak self] in
                    await self?.tempDownloadFileCreated(at: tempURL, destinationURL: destinationURL)
                    self?.itemReplacementDirectoryFSOCancellable = nil
                }
            })

            Logger.fileDownload.debug("download task callback: temp file: \(tempURL.path)")
            return tempURL

        } catch {
            await MainActor.run {
                Logger.fileDownload.error("🛑 download task callback: \(self): \(error)")

                self.download.cancel()
                self.finish(with: .failure(.failedToCompleteDownloadTask(underlyingError: error, resumeData: nil, isRetryable: false)))
                PixelKit.fire(DebugEvent(GeneralPixel.fileGetDownloadLocationFailed, error: error))
            }
            return nil
        }
    }

    /// create sandbox-accessible temporary directory on the same volume with the desired destination URL and notify on the download file creation
    private nonisolated func setupTemporaryDownloadURL(for destinationURL: URL, fileAddedHandler: @escaping @MainActor (URL) -> Void) async throws -> URL {
        let itemReplacementDirectory = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: destinationURL, create: true)
        let tempURL = itemReplacementDirectory.appendingPathComponent(destinationURL.lastPathComponent)

        // monitor our folder for download start
        let fileDescriptor = open(itemReplacementDirectory.path, O_EVTONLY)
        if fileDescriptor == -1 {
            let err = errno
            Logger.fileDownload.error("could not open \(itemReplacementDirectory.path): \(err) – \(String(cString: strerror(err)))")
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(err), userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(err))])
        }
        let fileMonitor = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: .main)

        // Set up a handler for file system events
        fileMonitor.setEventHandler {
            MainActor.assumeIsolated { // DispatchSource is set up with the main queue above
                fileAddedHandler(tempURL)
            }
        }
        await MainActor.run {
            self.itemReplacementDirectory = itemReplacementDirectory
            self.itemReplacementDirectoryFSOCancellable = AnyCancellable {
                fileMonitor.cancel()
                close(fileDescriptor)
            }
        }

        fileMonitor.resume()

        return tempURL
    }

    /// when the download has started to a temporary directory, create a placeholder file at the destination URL and move the temp file to the destination directory as a `.duckload`
    @MainActor
    private func tempDownloadFileCreated(at tempURL: URL, destinationURL: URL) async {
        Logger.fileDownload.debug("temp file created: \(self): \(tempURL.path)")

        do {
            let presenters = if case .downloading(destination: let destination, tempFile: let tempFile) = state {
                // when “resuming” a non-resumable download - use the existing file presenters
                try await self.reuseFilePresenters(tempFile: tempFile, destination: destination, tempURL: tempURL)
            } else {
                // instantiate File Presenters and move the temp file to the final destination directory
                try await self.filePresenters(for: destinationURL, tempURL: tempURL)
            }
            self.state = .downloading(destination: presenters.destinationFile, tempFile: presenters.tempFile)

        } catch {
            Logger.fileDownload.error("🛑 file presenters failure: \(self): \(error)")

            self.download.cancel()

            self.finish(with: .failure(.failedToCompleteDownloadTask(underlyingError: error, resumeData: nil, isRetryable: false)))

            PixelKit.fire(DebugEvent(GeneralPixel.fileDownloadCreatePresentersFailed(osVersion: "\(ProcessInfo.processInfo.operatingSystemVersion)"), error: error))
        }
    }

    /// opens File Presenters for destination file and temp file
    private nonisolated func filePresenters(for destinationURL: URL, tempURL: URL) async throws -> (tempFile: FilePresenter, destinationFile: FilePresenter) {
        var destinationURL = destinationURL
        var duckloadURL = destinationURL.deletingPathExtension().appendingPathExtension(Self.downloadExtension)
        let fm = FileManager()

        // 🧙‍♂️ now we‘re doing do some magique here 🧙‍♂️
        // --------------------------------------
        Logger.fileDownload.debug("🧙‍♂️ magique.start: \"\(destinationURL.path)\" (\"\(duckloadURL.path)\") directory writable: \(fm.isWritableFile(atPath: destinationURL.deletingLastPathComponent().path))")
        // 1. create our final destination file (let‘s say myfile.zip) and setup a File Presenter for it
        //    doing this we preserve access to the file until it‘s actually downloaded
        let destinationFilePresenter = try BookmarkFilePresenter(url: destinationURL, consumeUnbalancedStartAccessingResource: true) { url in
            try fm.createFile(atPath: url.path, contents: nil) ? url : {
                throw CocoaError(.fileWriteNoPermission, userInfo: [NSFilePathErrorKey: url.path])
            }()
        }
        if duckloadURL == destinationURL {
            // corner-case when downloading a `.duckload` file - the source and destination files will be the same then
            return try await reuseFilePresenters(tempFile: destinationFilePresenter, destination: destinationFilePresenter, tempURL: tempURL)
        }

        // 2. mark the file as hidden until it‘s downloaded to not to confuse user
        //    and prevent from unintentional opening of the empty file
        try destinationURL.setFileHidden(true)
        Logger.fileDownload.debug("🧙‍♂️ \"\(destinationURL.path)\" hidden")

        // 3. then we move the temporary download file to the destination directory (myfile.duckload)
        //    this is doable in sandboxed builds by using “Related Items” i.e. using a file URL with an extra
        //    `.duckload` extension appended and “Primary Item” pointing to the sandbox-accessible destination URL
        //    the `.duckload` document type is registered in the Info.plist with `NSIsRelatedItemType` flag
        //
        // -  after the file is downloaded we‘ll replace the destination file with the `.duckload` file
        if fm.fileExists(atPath: duckloadURL.path) {
            // `.duckload` already exists
            do {
                try chooseAlternativeDuckloadFileNameOrRemove(&duckloadURL, destinationURL: destinationURL)
            } catch {
                // that‘s ok, we‘ll keep using the original temp file
                Logger.fileDownload.error("❗️ can‘t resolve duckload file exists: \"\(duckloadURL.path)\": \(error)")
                duckloadURL = tempURL
            }
        }

        let tempFilePresenter = if duckloadURL == tempURL {
            // we won‘t use a `.duckload` file for this download, the file will be left in the temp location instead
            try BookmarkFilePresenter(url: duckloadURL)
        } else {
            // now move the temp file to `.duckload` instantiating a File Presenter with it
            try BookmarkFilePresenter(url: duckloadURL, primaryItemURL: destinationURL) { duckloadURL in
                do {
                    try fm.moveItem(at: tempURL, to: duckloadURL)
                    return duckloadURL
                } catch {
                    // fallback: move failed, keep the temp file in the original location
                    Logger.fileDownload.error("🙁 fallback with \(error), will use \(tempURL.path)")
                    PixelKit.fire(DebugEvent(GeneralPixel.fileAccessRelatedItemFailed, error: error))
                    return tempURL
                }
            }
        }
        Logger.fileDownload.debug("🧙‍♂️ \"\(duckloadURL.path)\" (\"\(tempFilePresenter.url?.path ?? "<nil>")\") ready")

        return (tempFile: tempFilePresenter, destinationFile: destinationFilePresenter)
    }

    private func chooseAlternativeDuckloadFileNameOrRemove(_ duckloadURL: inout URL, destinationURL: URL) throws {
        let fm = FileManager()
        // are we using the `.duckload` file for some other download (with different extension)?
        if NSFileCoordinator.filePresenters.first(where: { $0.presentedItemURL?.resolvingSymlinksInPath() == duckloadURL.resolvingSymlinksInPath() }) != nil {
            // if the downloads directory is writable without extra permission – try choosing another `.duckload` filename
            if fm.isWritableFile(atPath: duckloadURL.deletingLastPathComponent().path) {
                // append `.duckload` to the destination file name with extension
                let destinationPathExtension = destinationURL.pathExtension
                let pathExtension = destinationPathExtension.isEmpty ? Self.downloadExtension : destinationPathExtension + "." + Self.downloadExtension
                duckloadURL = duckloadURL.deletingPathExtension().appendingPathExtension(pathExtension)

                // choose non-existent path
                duckloadURL = try fm.withNonExistentUrl(for: duckloadURL, incrementingIndexIfExistsUpTo: 1000, pathExtension: pathExtension) { url in
                    try Data().write(to: url)
                    return url
                }
            } else {
                // continue keeping the temp file in the temp dir
                throw CocoaError(.fileWriteFileExists)
            }
        }

        Logger.fileDownload.debug("Removing temp file")
        try FilePresenter(url: duckloadURL, primaryItemURL: destinationURL).coordinateWrite(with: .forDeleting) { duckloadURL in
            try fm.removeItem(at: duckloadURL)
        }
    }

    private nonisolated func reuseFilePresenters(tempFile: FilePresenter, destination: FilePresenter, tempURL: URL) async throws -> (tempFile: FilePresenter, destinationFile: FilePresenter) {
        // if the download is “resumed” as a new download (replacing the destination file) -
        // use the existing `.duckload` file and move the temp file in its place
        _=try tempFile.coordinateWrite(with: .forReplacing) { duckloadURL in
            try FileManager.default.replaceItemAt(duckloadURL, withItemAt: tempURL)
        }

        return (tempFile: tempFile, destinationFile: destination)
    }

    func cancel() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.cancel()
            }
            return
        }
        Logger.fileDownload.debug("cancel \(self)")
        download.cancel { [weak self, taskDescr=self.debugDescription] resumeData in
            Logger.fileDownload.debug("\(taskDescr): download.cancel callback")
            DispatchQueue.main.asyncOrNow {
                self?.downloadDidFail(with: URLError(.cancelled), resumeData: resumeData)
            }
        }
    }

    @MainActor
    private func finish(with result: Result<FilePresenter, FileDownloadError>) {
        assert(state.isInitial || state.isDownloading)
        fileProgressPresenter = nil
        itemReplacementDirectoryFSOCancellable = nil // in case we‘ve failed without the temp file been created

        switch result {
        case .success(let presenter):
            let url = presenter.url
            Logger.fileDownload.debug("finish \(self) with .success(\"\(url?.path ?? "<nil>")\")")

            if progress.totalUnitCount == -1 {
                progress.totalUnitCount = max(1, self.progress.completedUnitCount)
            }
            progress.completedUnitCount = progress.totalUnitCount

            self.state = .downloaded(presenter)

        case .failure(let error):
            Logger.fileDownload.debug("finish \(self) with .failure(\(error))")

            self.state = .failed(destination: error.isRetryable ? self.state.destinationFilePresenter : nil, // stop tracking removed files for non-retryable downloads
                                 tempFile: error.isRetryable ? self.state.tempFilePresenter : nil,
                                 resumeData: error.resumeData,
                                 error: error)
        }

        self.delegate?.fileDownloadTask(self, didFinishWith: result.map { _ in })

        // temp dir cleanup
        if let itemReplacementDirectory,
           // don‘t remove itemReplacementDirectory if we‘re keeping the temp file in it for a retryable error
           self.state.tempFilePresenter?.url?.path.hasPrefix(itemReplacementDirectory.path) != true {

            DispatchQueue.global().async { [itemReplacementDirectory] in
                Logger.fileDownload.debug("removing \"\(itemReplacementDirectory.path)\"")
                try? FileManager.default.removeItem(at: itemReplacementDirectory)
            }
            self.itemReplacementDirectory = nil
        }
    }

    @MainActor
    private func downloadDidFail(with error: Error, resumeData: Data?) {
        guard case .downloading(destination: let destinationFile, tempFile: let tempFile) = self.state else {
            // cancelled at early stage
            if state.isInitial {
                self.finish(with: .failure(.failedToCompleteDownloadTask(underlyingError: error, resumeData: nil, isRetryable: false)))
                return
            }
            Logger.fileDownload.debug("ignoring `cancel` for already completed task \(self)")
            return
        }

        // disable retrying download for user-removed/trashed files or fire windows downloads
        let isRetryable: Bool
        if let url = tempFile.url {
            let fileExists = FileManager.default.fileExists(atPath: url.path)
            let isInTrash = FileManager.default.isInTrash(url)
            let isFromFireWindow = fireWindowSession != nil
            isRetryable = fileExists && !isInTrash && !isFromFireWindow
        } else {
            isRetryable = false
        }

        Logger.fileDownload.debug("❗️ downloadDidFail \(self): \(error), retryable: \(isRetryable)")
        self.finish(with: .failure(.failedToCompleteDownloadTask(underlyingError: error, resumeData: resumeData, isRetryable: isRetryable)))

        if !isRetryable {
            DispatchQueue.global().async { [itemReplacementDirectory] in
                let fm = FileManager()
                try? destinationFile.coordinateWrite(with: .forDeleting) { url in
                    Logger.fileDownload.debug("removing \"\(url.path)\"")
                    try fm.removeItem(at: url)
                }
                try? tempFile.coordinateWrite(with: .forDeleting) { url in
                    var url = url
                    // if temp file is still in the itemReplacementDirectory - remove the itemReplacementDirectory
                    if let itemReplacementDirectory, url.path.hasPrefix(itemReplacementDirectory.path) {
                        url = itemReplacementDirectory
                    }
                    Logger.fileDownload.debug("removing \"\(url.path)\"")
                    try fm.removeItem(at: url)
                }
            }
            self.itemReplacementDirectory = nil
        }
    }

    /// when `downloadDidFinish` or `downloadDidFail` callback is received before File Presenters finish initialization -
    /// we wait for the `state` to switch to `.downloading` and re-call the callback
    private func waitForDownloadDidStart(completionHandler: @escaping @MainActor () -> Void) {
        var cancellable: AnyCancellable?
        cancellable = $state.receive(on: DispatchQueue.main).sink { state in
            withExtendedLifetime(cancellable) {
                switch state {
                case .initial: return
                case .downloading:
                    MainActor.assumeIsolated(completionHandler)
                    cancellable = nil
                case .downloaded:
                    pixelAssertionFailure("unexpected state change to \(state)")
                    fallthrough
                case .failed:
                    // something went wrong while initializing File Presenters, but we‘re already completed
                    cancellable = nil
                }
            }
        }
    }

    deinit {
#if DEBUG
        let downloadDescr = download.debugDescription
        @MainActor(unsafe) func performRegardlessOfMainThread() {
            Logger.fileDownload.debug("<Task \(downloadDescr)>.deinit")
            assert(state.isCompleted, "FileDownloadTask is deallocated without finish(with:) been called")
        }
        performRegardlessOfMainThread()
#endif

        // WebKit objects must be deallocated on the main thread on pre-macOS 12
        if #unavailable(macOS 12), !Thread.isMainThread {
            let extendLifetime = DispatchWorkItem { [download] in
                withExtendedLifetime(download) {}
            }
            // to avoid race condition we clear the ivar first,
            // then pass the WKDownload lifetime extension to the main queue
            self.download = nil
            DispatchQueue.main.async(execute: extendLifetime)
        }
    }

}

extension WebKitDownloadTask: WKDownloadDelegate {

    @MainActor
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String) async -> URL? {
        Logger.fileDownload.debug("decide destination \(self)")

        guard let delegate = delegate else {
            assertionFailure("WebKitDownloadTask: delegate is gone")
            return nil
        }

        let suggestedFileType: UTType? = {
            guard var mimeType = response.mimeType else { return nil }
            // drop ;charset=.. from "text/plain;charset=utf-8"
            if let charsetRange = mimeType.range(of: ";charset=") {
                mimeType = String(mimeType[..<charsetRange.lowerBound])
            }
            return UTType(mimeType: mimeType)
        }()
        if progress.totalUnitCount <= 0 {
            progress.totalUnitCount = response.expectedContentLength
        }

        var suggestedFilename = (suggestedFilename.removingPercentEncoding ?? suggestedFilename).replacingInvalidFileNameCharacters()
        // sometimes suggesteFilename has an extension appended to already present URL file extension
        // e.g. feed.xml.rss for www.domain.com/rss.xml
        if let urlSuggestedFilename = response.url?.suggestedFilename,
           !(urlSuggestedFilename.pathExtension.isEmpty || (suggestedFileType == .html && urlSuggestedFilename.pathExtension == "html")),
           suggestedFilename.hasPrefix(urlSuggestedFilename) {
            suggestedFilename = urlSuggestedFilename
        }

        var cleanupStyle: DestinationCleanupStyle = .remove
        guard let destinationURL = switch state {
        case .initial(.auto), .initial(.prompt):
            await delegate.fileDownloadTaskNeedsDestinationURL(self, suggestedFilename: suggestedFilename, suggestedFileType: suggestedFileType).0
        case .initial(.preset(let destinationURL)):
            destinationURL
        case .initial(.resume(destination: let destination, tempFile: _)): {
            cleanupStyle = .clear
            return destination.url
        }()
        case .downloading, .downloaded, .failed: {
            assertionFailure("Unexpected state in decideDestination callback – \(state)")
            return nil
        }()
        } else {
            return nil
        }

        self.selectedDestinationURL = destinationURL
        return await prepareChosenDestinationURL(destinationURL, fileType: suggestedFileType, cleanupStyle: cleanupStyle)
    }

    @MainActor
    func download(_ download: WKDownload,
                  willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest,
                  decisionHandler: @escaping (WKDownload.RedirectPolicy) -> Void) {
        Logger.fileDownload.debug("will perform HTTP redirection \(self): \(response) to \(request)")
        decisionHandler(.allow)
    }

    @MainActor
    func download(_ download: WKDownload,
                  didReceive challenge: URLAuthenticationChallenge,
                  completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        Logger.fileDownload.debug("did receive challenge \(self): \(challenge)")
        download.webView?.navigationDelegate?.webView?(download.webView!, didReceive: challenge, completionHandler: completionHandler) ?? {
            completionHandler(.performDefaultHandling, nil)
        }()
    }

    @MainActor
    func downloadDidFinish(_ download: WKDownload) {
        let fm = FileManager.default

        guard case .downloading(destination: let destinationFile, tempFile: let tempFile) = self.state else {
            // if we receive `downloadDidFinish:` before the File Presenters are set up (async)
            // - we‘ll be waiting for the `.downloading` state to come in with the presenters
            Logger.fileDownload.debug("🏁 download did finish too early, we‘ll wait for the `.downloading` state: \(self)")
            assert(itemReplacementDirectory != nil, "itemReplacementDirectory should be set")
            waitForDownloadDidStart { [weak self] in
                self?.downloadDidFinish(download)
            }
            return
        }
        Logger.fileDownload.debug("🏁 download did finish: \(self)")

        do {
            try tempFile.coordinateWrite(with: .forMoving) { tempURL in
                // replace destination file with temp file
                try destinationFile.coordinateWrite(with: .forReplacing) { destinationURL in
                    if destinationURL != tempURL { // could be a corner-case when downloading a `.duckload` file
                        Logger.fileDownload.debug("replacing \"\(destinationURL.path)\" with \"\(tempURL.path)\"")
                        _=try fm.replaceItemAt(destinationURL, withItemAt: tempURL)
                    }
                    // set quarantine attributes
                    try? destinationURL.setQuarantineAttributes(sourceURL: originalRequest?.url, referrerURL: originalRequest?.mainDocumentURL)
                }
            }
            // remove temp file item replacement directory if present
            if let itemReplacementDirectory {
                Logger.fileDownload.debug("removing \(itemReplacementDirectory.path)")
                try? fm.removeItem(at: itemReplacementDirectory)
                self.itemReplacementDirectory = nil
            }
            self.finish(with: .success(destinationFile))

        } catch {
            PixelKit.fire(DebugEvent(GeneralPixel.fileMoveToDownloadsFailed, error: error))
            Logger.fileDownload.error("fileMoveToDownloadsFailed: \(error)")
            self.finish(with: .failure(.failedToCompleteDownloadTask(underlyingError: error, resumeData: nil, isRetryable: false)))
        }
    }

    @MainActor
    func download(_: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        // if we receive `downloadDidFail:` before File Presenters are set up (async)
        // - we‘ll be waiting for the `.downloading` state to come in with the presenters
        guard state.isDownloading
                // in case the File Presenters instantiation task is still running - we‘ll either receive the `state` change
                // or the task will be finished with a file error
                || itemReplacementDirectoryFSOCancellable == nil else {
            Logger.fileDownload.debug("❌ download did fail too early, we‘ll wait for the `.downloading` state: \(self)")
            waitForDownloadDidStart { [weak self] in
                self?.downloadDidFail(with: error, resumeData: resumeData)
            }
            return
        }
        downloadDidFail(with: error, resumeData: resumeData)
    }

}

extension WebKitDownloadTask {

    var didChooseDownloadLocationPublisher: AnyPublisher<URL, FileDownloadError> {
        $state.tryCompactMap { state in
            switch state {
            case .initial:
                return nil
            case .downloading(destination: let destinationFile, _),
                 .downloaded(let destinationFile):
                return destinationFile.url
            case .failed(_, _, resumeData: _, error: let error):
                throw error
            }
        }
        .mapError { $0 as! FileDownloadError } // swiftlint:disable:this force_cast
        .first()
        .eraseToAnyPublisher()
    }

}

extension WebKitDownloadTask {

    override var description: String {
        guard Thread.isMainThread else {
#if DEBUG
            breakByRaisingSigInt("❗️accessing WebKitDownloadTask.description from non-main thread")
#endif
            return ""
        }
        return MainActor.assumeIsolated {
            "<Task \(download!) – \(state)>"
        }
    }

}

extension WebKitDownloadTask.FileDownloadState: CustomDebugStringConvertible {

    var debugDescription: String {
        switch self {
        case .initial(let destination):
            ".initial(\(destination))"
        case .downloading(destination: let destination, tempFile: let tempFile):
            ".downloading(dest: \"\(destination.url?.path ?? "<nil>")\", temp: \"\(tempFile.url?.path ?? "<nil>")\")"
        case .downloaded(let destination):
            ".downloaded(dest: \"\(destination.url?.path ?? "<nil>")\")"
        case .failed(destination: let destination, tempFile: let tempFile, resumeData: let resumeData, error: let error):
            ".failed(dest: \"\(destination?.url?.path ?? "<nil>")\", temp: \"\(tempFile?.url?.path ?? "<nil>")\", resumeData: \(resumeData?.description ?? "<nil>") error: \(error))"
        }
    }

}
