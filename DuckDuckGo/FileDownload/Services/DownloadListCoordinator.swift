//
//  DownloadListCoordinator.swift
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

import Combine
import Common
import Foundation
import Navigation
import PixelKit
import os.log

@MainActor
private func getFirstAvailableWebView() -> WKWebView? {
    let wcm = WindowControllersManager.shared
    if wcm.lastKeyMainWindowController?.mainViewController.browserTabViewController == nil {
        WindowsManager.openNewWindow()
    }

    guard let tab = wcm.lastKeyMainWindowController?.mainViewController.browserTabViewController.tabViewModel?.tab else {
        assertionFailure("Expected to have an open window")
        return nil
    }
    return tab.webView
}

final class DownloadListCoordinator {
    static let shared = DownloadListCoordinator()

    private let store: DownloadListStoring
    private let downloadManager: FileDownloadManagerProtocol
    private let webViewProvider: (() -> WKWebView?)?

    private var items = [UUID: DownloadListItem]()

    private var downloadsCancellable: AnyCancellable?
    private var downloadTaskCancellables = [WebKitDownloadTask: AnyCancellable]()
    private var taskProgressCancellables = [WebKitDownloadTask: Set<AnyCancellable>]()
    @MainActor private var fireWindowSessions = Set<FireWindowSessionRef>()

    private var filePresenters = [UUID: (destination: FilePresenter?, tempFile: FilePresenter?)]()
    private var filePresenterCancellables = [UUID: Set<AnyCancellable>]()

    enum UpdateKind {
        case added
        case removed
        case updated(oldValue: DownloadListItem)
    }
    struct Update {
        let kind: UpdateKind
        let item: DownloadListItem
    }
    private let updatesSubject = PassthroughSubject<Update, Never>()

    private let regularWindowDownloadProgress = Progress()
    @MainActor private var fireWindowSessionsProgress = [FireWindowSessionRef: Progress]()

    init(store: DownloadListStoring = DownloadListStore(),
         downloadManager: FileDownloadManagerProtocol = FileDownloadManager.shared,
         clearItemsOlderThan clearDate: Date = .daysAgo(2),
         webViewProvider: (() -> WKWebView?)? = nil) {

        self.store = store
        self.downloadManager = downloadManager
        self.webViewProvider = webViewProvider

        load(clearingItemsOlderThan: clearDate)
        subscribeToDownloadManager()
    }

    private func load(clearingItemsOlderThan clearDate: Date) {
        store.fetch { [weak self] result in
            // WebKitDownloadTask should be used from the Main Thread (even in callbacks: see a notice below)
            dispatchPrecondition(condition: .onQueue(.main))
            guard let self = self else { return }

            switch result {
            case .success(let items):
                Logger.fileDownload.error("coordinator: loaded \(items.count) items")
                for item in items {
                    do {
                        try add(item, ifModifiedLaterThan: clearDate)
                    } catch {
                        Logger.fileDownload.debug("❗️ coordinator: drop item \(item.identifier): \(error)")
                        // remove item from db removing temp files if needed without sending a `.removed` update
                        cleanupTempFiles(for: item)
                        filePresenters[item.identifier] = nil
                        filePresenterCancellables[item.identifier] = nil
                        self.items[item.identifier] = nil
                        store.remove(item)
                    }
                }

            case .failure(let error):
                Logger.fileDownload.error("coordinator: loading failed: \(error)")
            }
        }
    }

    private func subscribeToDownloadManager() {
        assert(downloadManager.downloads.isEmpty)
        downloadsCancellable = downloadManager.downloadsPublisher
            .sink { [weak self] task in
                DispatchQueue.main.async {
                    self?.subscribeToDownloadTask(task)
                }
            }
    }

    private enum FileAddError: Error {
        case urlIsNil
        case fileInTrash
        case noDestinationUrl
        case itemOutdated
    }
    private func add(_ item: DownloadListItem, ifModifiedLaterThan minModificationDate: Date) throws {
        var item = item
        let modified = item.modified // setting error would reset `.modified`
        if item.tempURL != nil, item.error == nil {
            // initially loaded item with non-nil `tempURL` means the browser was terminated without writing a cancellation error
            item.error = .failedToCompleteDownloadTask(underlyingError: URLError(.cancelled), resumeData: nil, isRetryable: false)
        }
        self.items[item.identifier] = item

        let presenters = try setupFilePresenters(for: item)

        // clear old downloads
        guard modified > minModificationDate else { throw FileAddError.itemOutdated }
        guard let destinationFilePresenter = try presenters.destination.get() else { throw FileAddError.noDestinationUrl }

        self.subscribeToPresenters((destination: destinationFilePresenter, tempFile: try? presenters.tempFile.get()), of: item)
        self.updatesSubject.send(Update(kind: .added, item: item))
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func setupFilePresenters(for item: DownloadListItem) throws -> (destination: Result<FilePresenter?, Error>, tempFile: Result<FilePresenter?, Error>) {
        let fm = FileManager.default

        // locate destination file
        let destinationPresenterResult = Result<FilePresenter?, Error> {
            if let destinationFileBookmarkData = item.destinationFileBookmarkData {
                try BookmarkFilePresenter(fileBookmarkData: destinationFileBookmarkData)
            } else if let destinationURL = item.destinationURL {
                try BookmarkFilePresenter(url: destinationURL)
            } else {
                nil
            }
        }

        // locate temp download file
        var tempFilePresenterResult = Result<FilePresenter?, Error> {
            if let tempFileBookmarkData = item.tempFileBookmarkData {
                try BookmarkFilePresenter(fileBookmarkData: tempFileBookmarkData)
            } else if let tempURL = item.tempURL {
                try BookmarkFilePresenter(url: tempURL)
            } else {
                nil
            }
        }
        // corner-case when downloading a `.duckload` file - the source and destination files will be the same then
        if (try? tempFilePresenterResult.get()?.url) == (try? destinationPresenterResult.get()?.url) {
            tempFilePresenterResult = destinationPresenterResult
        }
        self.filePresenters[item.identifier] = (destination: try? destinationPresenterResult.get(), tempFile: try? tempFilePresenterResult.get())

        // validate file exists and not in the Trash
        for result in [destinationPresenterResult, tempFilePresenterResult] {
            guard let presenter = try? result.get() else { continue }

            // presented file should have URL
            guard let url = presenter.url else { throw FileAddError.urlIsNil }
            // presented file should exist
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: url.path]) }
            // the file should not be in the Trash
            guard !fm.isInTrash(url) else { throw FileAddError.fileInTrash }
            // it should be a file, not a directory
            guard !isDirectory.boolValue else { throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: url.path]) }
        }

        return (destinationPresenterResult, tempFilePresenterResult)
    }

    @MainActor(unsafe)
    private func subscribeToDownloadTask(_ task: WebKitDownloadTask, updating item: DownloadListItem? = nil) {
        dispatchPrecondition(condition: .onQueue(.main))

        if let identifier = item?.identifier {
            updateItem(withId: identifier) { item in
                // restarting existing download
                item?.error = nil
                item?.progress = task.progress
            }
        }
        // skip already known task: it's already subscribed
        guard downloadTaskCancellables[task] == nil else { return }

        let item = item ?? DownloadListItem(task: task)
        Logger.fileDownload.debug("coordinator: subscribing to \(item.identifier)")

        self.downloadTaskCancellables[task] = task.$state
            .sink { [weak self] state in
                DispatchQueue.main.async {
                    guard let self else { return }
                    Logger.fileDownload.debug("coordinator: state updated \(item.identifier.uuidString) ➡️ \(state.debugDescription)")
                    switch state {
                    case .initial:
                        // only add item when download starts, destination URL is set
                        return
                    case .downloading(destination: let destination, tempFile: let tempFile):
                        self.addItemIfNeededAndSubscribe(to: (destination, tempFile), for: item)
                    case .downloaded(let destination):
                        let updatedItem = self.downloadTask(task, withOriginalItem: item, completedWith: .finished)
                        self.subscribeToPresenters((destination: destination, tempFile: nil), of: updatedItem ?? item)
                    case .failed(destination: let destination, tempFile: let tempFile, resumeData: _, error: let error):
                        let updatedItem = self.downloadTask(task, withOriginalItem: item, completedWith: .failure(error))
                        self.subscribeToPresenters((destination: destination, tempFile: tempFile), of: updatedItem ?? item)
                    }
                }
            }

        if let fireWindowSession = task.fireWindowSession,
           case (inserted: true, _) = self.fireWindowSessions.insert(fireWindowSession) {
            // remove inactive items when the burner window is closed
            fireWindowSession.onBurn { [weak self] in
                self?.clearBurnerWindowItems(for: fireWindowSession)
            }
        }

        self.subscribeToProgress(of: task)
    }

    @MainActor
    private func addItemIfNeededAndSubscribe(to presenters: (destination: FilePresenter, tempFile: FilePresenter?), for initialItem: DownloadListItem) {
        Logger.fileDownload.debug("coordinator: add/update \(initialItem.identifier)")
        updateItem(withId: initialItem.identifier) { item in
            if item == nil { item = initialItem }
        }
        subscribeToPresenters(presenters, of: initialItem)
    }

    private func subscribeToPresenters(_ presenters: (destination: FilePresenter?, tempFile: FilePresenter?), of item: DownloadListItem) {
        var cancellables = Set<AnyCancellable>()
        filePresenters[item.identifier] = presenters

        Publishers.CombineLatest(
            presenters.destination?.urlPublisher ?? Just(nil).eraseToAnyPublisher(),
            (presenters.destination as? BookmarkFilePresenter)?.fileBookmarkDataPublisher ?? Just(nil).eraseToAnyPublisher()
        )
        .scan((oldURL: nil, newURL: nil, fileBookmarkData: nil)) { (oldURL: $0.newURL, newURL: $1.0, fileBookmarkData: $1.1) }
        .sink { [weak self] oldURL, newURL, fileBookmarkData in
            DispatchQueue.main.asyncOrNow {
                self?.updateItem(withId: item.identifier) { [id=item.identifier] item in
                    guard !Self.checkIfFileWasRemoved(oldURL: oldURL, newURL: newURL) else {
                        Logger.fileDownload.debug("coordinator: destination file removed \(id)")
                        item = nil
                        return
                    }

                    Logger.fileDownload.debug("⚠️coordinator: destination url updated \(id): \"\(newURL?.path ?? "<nil>")\"")
                    item?.destinationURL = newURL
                    item?.destinationFileBookmarkData = fileBookmarkData
                    // keep the filename even when the destinationURL is nullified
                    let fileName = if let lastPathComponent = newURL?.lastPathComponent, !lastPathComponent.isEmpty {
                        lastPathComponent
                    } else {
                        item?.fileName ?? ""
                    }
                    item?.fileName = fileName
                }
            }
        }
        .store(in: &cancellables)

        Publishers.CombineLatest(
            presenters.tempFile?.urlPublisher ?? Just(nil).eraseToAnyPublisher(),
            (presenters.tempFile as? BookmarkFilePresenter)?.fileBookmarkDataPublisher ?? Just(nil).eraseToAnyPublisher()
        )
        .scan((oldURL: nil, newURL: nil, fileBookmarkData: nil)) { (oldURL: $0.newURL, newURL: $1.0, fileBookmarkData: $1.1) }
        .sink { [weak self] oldURL, newURL, fileBookmarkData in
            DispatchQueue.main.asyncOrNow {
                self?.updateItem(withId: item.identifier) { [id=item.identifier] item in
                    guard !Self.checkIfFileWasRemoved(oldURL: oldURL, newURL: newURL) else {
                        Logger.fileDownload.debug("coordinator: temp file removed \(id)")
                        item = nil
                        return
                    }

                    Logger.fileDownload.debug("coordinator: temp url updated \(id): \"\(newURL?.path ?? "<nil>")\"")
                    item?.tempURL = newURL
                    item?.tempFileBookmarkData = fileBookmarkData
                }
            }
        }
        .store(in: &cancellables)

        filePresenterCancellables[item.identifier] = cancellables
    }

    private static func checkIfFileWasRemoved(oldURL: URL?, newURL: URL?) -> Bool {
        // if the file was removed by user after the download has failed or finished
        let fm = FileManager.default
        if oldURL != nil, // it should‘ve been there when we started observing but removed/trashed after
           newURL == nil || newURL.map({ !fm.fileExists(atPath: $0.path) || fm.isInTrash($0) }) == true {
            return true
        }
        return false
    }

    @MainActor
    func combinedDownloadProgressCreatingIfNeeded(for fireWindowSession: FireWindowSessionRef?) -> Progress {
        guard let fireWindowSession else { return regularWindowDownloadProgress }

        return fireWindowSessionsProgress[fireWindowSession] ?? {
            let progress = Progress()
            fireWindowSessionsProgress[fireWindowSession] = progress
            return progress
        }()
    }

    @MainActor
    private func subscribeToProgress(of task: WebKitDownloadTask) {
        dispatchPrecondition(condition: .onQueue(.main))

        var lastKnownProgress = (total: Int64(0), completed: Int64(0))
        let progress = self.combinedDownloadProgressCreatingIfNeeded(for: task.fireWindowSession)
        task.progress.publisher(for: \.totalUnitCount)
            .combineLatest(task.progress.publisher(for: \.completedUnitCount))
            .throttle(for: 0.2, scheduler: DispatchQueue.main, latest: true)
            .sink { (total, completed) in
                guard total > 0, completed > 0 else { return }

                progress.totalUnitCount += (total - lastKnownProgress.total)
                progress.completedUnitCount += (completed - lastKnownProgress.completed)
                lastKnownProgress = (total, completed)
            }
            .store(in: &self.taskProgressCancellables[task, default: []])

        task.$state.receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self, state.isCompleted else { return }
                Logger.fileDownload.debug("coordinator: unsubscribe from progress: \(task)")

                progress.completedUnitCount -= lastKnownProgress.completed
                progress.totalUnitCount -= lastKnownProgress.total
                taskProgressCancellables[task] = nil
            }
            .store(in: &self.taskProgressCancellables[task, default: []])
    }

    @MainActor
    private func downloadTask(_ task: WebKitDownloadTask, withOriginalItem initialItem: DownloadListItem, completedWith result: Subscribers.Completion<FileDownloadError>) -> DownloadListItem? {
        Logger.fileDownload.debug("coordinator: task did finish \(initialItem.identifier.uuidString) \(task.debugDescription) with .\(String(describing: result))")

        self.downloadTaskCancellables[task] = nil

        return updateItem(withId: initialItem.identifier) { item in
            if let fireWindowSession = (item ?? initialItem).fireWindowSession,
               !fireWindowSession.isActive {
                // remove finished downloads from the list instantly for downloads in already closed burner window
                item = nil
                return
            }

            if item == nil,
                case .failure(let failure) = result, !failure.isCancelled,
                let fileName = task.selectedDestinationURL?.lastPathComponent {
                // add instantly failed downloads to the list (not user-cancelled)
                item = initialItem
                item?.fileName = fileName
            }

            item?.progress = nil
            if case .failure(let error) = result {
                item?.error = error
            } else {
                item?.tempURL = nil
            }
        }
    }

    @MainActor
    @discardableResult
    private func updateItem(withId identifier: UUID, mutate: (inout DownloadListItem?) -> Void) -> DownloadListItem? {
        let original = self.items[identifier]
        var modified = original
        mutate(&modified)
        guard modified?.modified != original?.modified else { return modified }

        self.items[identifier] = modified

        switch (original, modified) {
        case (.none, .none):
            break
        case (.none, .some(let item)):
            self.updatesSubject.send(Update(kind: .added, item: item))
            store.save(item)
        case (.some(let oldValue), .some(let item)):
            self.updatesSubject.send(Update(kind: .updated(oldValue: oldValue), item: item))
            store.save(item)
        case (.some(let item), .none):
            item.progress?.cancel()
            if original != nil {
                self.updatesSubject.send(Update(kind: .removed, item: item))
            }
            cleanupTempFiles(for: item)
            filePresenters[item.identifier] = nil
            filePresenterCancellables[item.identifier] = nil
            store.remove(item)
        }
        return modified
    }

    private func cleanupTempFiles(for item: DownloadListItem) {
        let fm = FileManager.default
        do {
            try filePresenters[item.identifier]?.tempFile?.coordinateWrite(with: .forDeleting, using: { url in
                Logger.fileDownload.debug("🦀 coordinator: removing \"\(url.path)\" (\(item.identifier))")
                try fm.removeItem(at: url)
            })
        } catch {
            Logger.fileDownload.error("🦀 coordinator: failed to remove temp file: \(error)")
        }

        struct DestinationFileNotEmpty: Error {}
        do {
            guard let presenter = filePresenters[item.identifier]?.destination,
                  (try? presenter.url?.resourceValues(forKeys: [.fileSizeKey]).fileSize) == 0 else { throw DestinationFileNotEmpty() }
            try presenter.coordinateWrite(with: .forDeleting, using: { url in
                Logger.fileDownload.debug("🦀 coordinator: removing \"\(url.path)\" (\(item.identifier))")
                try fm.removeItem(at: url)
            })
        } catch is DestinationFileNotEmpty {
            // don‘t delete non-empty destination file
        } catch {
            Logger.fileDownload.error("🦀 coordinator: failed to remove destination file: \(error)")
        }
    }

    private func downloadRestartedCallback(for item: DownloadListItem, webView: WKWebView, presenters: (destination: FilePresenter, tempFile: FilePresenter)?) -> @MainActor (WebKitDownload) -> Void {
        return { @MainActor download in
            // Important: WebKitDownloadTask (as well as WKWebView) should be deallocated on the Main Thread
            dispatchPrecondition(condition: .onQueue(.main))
            withExtendedLifetime(webView) {
                Logger.fileDownload.debug("coordinator: restarting \(item.identifier.uuidString): \(String(describing: download))")
                let destination: WebKitDownloadTask.DownloadDestination = if let presenters {
                    .resume(destination: presenters.destination, tempFile: presenters.tempFile)
                } else {
                    .auto
                }
                let task = self.downloadManager.add(download, fireWindowSession: item.fireWindowSession, destination: destination)
                self.subscribeToDownloadTask(task, updating: item)
            }
        }
    }

    // MARK: interface

    func hasActiveDownloads(for fireWindowSession: FireWindowSessionRef?) -> Bool {
        for task in downloadTaskCancellables.keys where task.fireWindowSession == fireWindowSession {
            return true
        }
        return false
    }

    func hasDownloads(for fireWindowSession: FireWindowSessionRef?) -> Bool {
        return items.contains { _, item in
            item.fireWindowSession == fireWindowSession
        }
    }

    @MainActor
    func downloads<T: Comparable>(sortedBy keyPath: KeyPath<DownloadListItem, T>, ascending: Bool) -> [DownloadListItem] {
        return items.values.sorted {
            ascending ? ($0[keyPath: keyPath] < $1[keyPath: keyPath]) : ($0[keyPath: keyPath] > $1[keyPath: keyPath])
        }
    }

    var updates: AnyPublisher<Update, Never> {
        return updatesSubject.eraseToAnyPublisher()
    }

    @MainActor
    func restart(downloadWithIdentifier identifier: UUID) {
        Logger.fileDownload.debug("coordinator: restart \(identifier)")
        guard let item = items[identifier], let webView = (webViewProvider ?? getFirstAvailableWebView)() else { return }
        do {
            guard var resumeData = item.error?.resumeData,
                  case .some((destination: .some(let destination), tempFile: .some(let tempFile))) = filePresenters[item.identifier],
                  let tempURL = tempFile.url else {
                struct NoResumeData: Error {}
                throw NoResumeData()
            }

            do {
                var downloadResumeData = try DownloadResumeData(resumeData: resumeData)
                if downloadResumeData.localPath != tempURL.path {
                    downloadResumeData.localPath = tempURL.path
                    downloadResumeData.tempFileName = tempURL.lastPathComponent
                    resumeData = try downloadResumeData.data()
                }
            } catch {
                assertionFailure("Resume data coding failed: \(error)")
                PixelKit.fire(DebugEvent(GeneralPixel.downloadResumeDataCodingFailed, error: error))
            }

            webView.resumeDownload(fromResumeData: resumeData,
                                   completionHandler: self.downloadRestartedCallback(for: item,
                                                                                     webView: webView,
                                                                                     presenters: (destination: destination, tempFile: tempFile)))
        } catch {
            let presenters: (destination: FilePresenter, tempFile: FilePresenter)? = if case .some((destination: .some(let destination), tempFile: .some(let tempFile))) = filePresenters[item.identifier] {
                (destination, tempFile)
            } else {
                nil
            }
            let request = item.createRequest()
            webView.startDownload(using: request, completionHandler: self.downloadRestartedCallback(for: item, webView: webView, presenters: presenters))
        }
    }

    @MainActor
    func cleanupInactiveDownloads(for fireWindowSession: FireWindowSessionRef?) {
        Logger.fileDownload.debug("coordinator: cleanupInactiveDownloads")

        for (id, item) in self.items where item.fireWindowSession == fireWindowSession && item.progress == nil {
            remove(downloadWithIdentifier: id)
        }
    }

    @MainActor
    private func clearBurnerWindowItems(for fireWindowSession: FireWindowSessionRef) {
        Logger.fileDownload.debug("coordinator: cleanup Fire Window Downloads")

        for (id, item) in self.items where item.fireWindowSession == fireWindowSession {
            item.progress?.cancel()
            remove(downloadWithIdentifier: id)
        }
        fireWindowSessionsProgress[fireWindowSession] = nil
    }

    @MainActor
    func cleanupInactiveDownloads(for baseDomains: Set<String>, tld: TLD) {
        Logger.fileDownload.debug("coordinator: cleanupInactiveDownloads for \(baseDomains)")

        for (id, item) in self.items where item.progress == nil {
            let websiteUrlBaseDomain = tld.eTLDplus1(item.websiteURL?.host) ?? ""
            let itemUrlBaseDomain = tld.eTLDplus1(item.downloadURL.host) ?? ""
            if baseDomains.contains(websiteUrlBaseDomain) ||
                baseDomains.contains(itemUrlBaseDomain) {
                remove(downloadWithIdentifier: id)
            }
        }
    }

    @MainActor
    func remove(downloadWithIdentifier identifier: UUID) {
        Logger.fileDownload.debug("coordinator: remove \(identifier)")

        updateItem(withId: identifier) { item in
            item = nil
        }
    }

    @MainActor
    func cancel(downloadWithIdentifier identifier: UUID) {
        Logger.fileDownload.debug("coordinator: cancel \(identifier)")

        guard let item = self.items[identifier] else {
            assertionFailure("Item with identifier \(identifier) not found")
            return
        }
        item.progress?.cancel()
    }

    func sync() {
        store.sync()
    }

}

private extension DownloadListItem {

    init(task: WebKitDownloadTask) {
        let now = Date()
        self.init(identifier: UUID(),
                  added: now,
                  modified: now,
                  downloadURL: task.originalRequest?.url ?? .blankPage,
                  websiteURL: task.originalRequest?.mainDocumentURL,
                  fileName: "",
                  progress: task.progress,
                  fireWindowSession: task.fireWindowSession,
                  error: nil)
    }

    func createRequest() -> URLRequest {
        var request = URLRequest(url: downloadURL)
        request.setValue(websiteURL?.absoluteString, forHTTPHeaderField: URLRequest.HeaderKey.referer.rawValue)
        return request
    }

}

extension DownloadListCoordinator.Update {

    var isDownloadCompletedUpdate: Bool {
        if case .updated(let oldValue) = kind,
           oldValue.progress != nil && item.progress == nil {
            true
        } else {
            false
        }
    }

}
