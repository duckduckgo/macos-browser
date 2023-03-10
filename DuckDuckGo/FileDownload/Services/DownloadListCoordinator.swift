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
import Foundation
import Navigation
import os.log

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
    private let webViewProvider: () -> WKWebView?

    private var items = [UUID: DownloadListItem]()

    private var downloadsCancellable: AnyCancellable?
    private var downloadTaskCancellables = [WebKitDownloadTask: Set<AnyCancellable>]()
    private var taskProgressCancellables = [WebKitDownloadTask: Set<AnyCancellable>]()

    enum UpdateKind {
        case added
        case removed
        case updated
    }
    typealias Update = (kind: UpdateKind, item: DownloadListItem)
    private let updatesSubject = PassthroughSubject<Update, Never>()

    let progress = Progress()

    init(store: DownloadListStoring = DownloadListStore(),
         downloadManager: FileDownloadManagerProtocol = FileDownloadManager.shared,
         clearItemsOlderThan clearDate: Date = .daysAgo(2),
         webViewProvider: @escaping () -> WKWebView? = getFirstAvailableWebView) {

        self.store = store
        self.downloadManager = downloadManager
        self.webViewProvider = webViewProvider

        load(clearingItemsOlderThan: clearDate)
        subscribeToDownloadManager()
    }

    private func load(clearingItemsOlderThan clearDate: Date) {
        store.fetch(clearingItemsOlderThan: clearDate) { [weak self] result in
            // WebKitDownloadTask should be used from the Main Thread (even in callbacks: see a notice below)
            dispatchPrecondition(condition: .onQueue(.main))

            guard let self = self else { return }

            switch result {
            case .success(let items):
                for item in items {
                    self.items[item.identifier] = item
                    self.updatesSubject.send((.added, item))
                }

            case .failure(let error):
                os_log("Cleaning and loading of downloads failed: %s", log: .history, type: .error, error.localizedDescription)
            }
        }
    }

    private func subscribeToDownloadManager() {
        assert(downloadManager.downloads.isEmpty)
        downloadsCancellable = downloadManager.downloadsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] task in
                self?.subscribeToDownloadTask(task)
            }
    }

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

        task.$location
            // only add item to the dict when destination URL is set
            .filter { $0.destinationURL != nil }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.addItemOrUpdateLocation(for: item, destinationURL: location.destinationURL, tempURL: location.tempURL)
            }
            .store(in: &self.downloadTaskCancellables[task, default: []])

        task.output
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.downloadTask(task, withId: item.identifier, completedWith: completion)
            } receiveValue: { _ in }
            .store(in: &self.downloadTaskCancellables[task, default: []])

        self.subscribeToProgress(of: task)
    }

    private func addItemOrUpdateLocation(for initialItem: DownloadListItem, destinationURL: URL?, tempURL: URL?) {
        dispatchPrecondition(condition: .onQueue(.main))

        updateItem(withId: initialItem.identifier) { item in
            if item == nil { item = initialItem }
            item!.destinationURL = destinationURL
            item!.tempURL = tempURL
        }
    }

    private func subscribeToProgress(of task: WebKitDownloadTask) {
        dispatchPrecondition(condition: .onQueue(.main))

        var lastKnownProgress = (total: Int64(0), completed: Int64(0))
        task.progress.publisher(for: \.totalUnitCount)
            .combineLatest(task.progress.publisher(for: \.completedUnitCount))
            .throttle(for: 0.2, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] (total, completed) in
                guard let self = self else { return }
                self.progress.totalUnitCount += (total - lastKnownProgress.total)
                self.progress.completedUnitCount += (completed - lastKnownProgress.completed)
                lastKnownProgress = (total, completed)
            }
            .store(in: &self.taskProgressCancellables[task, default: []])

        task.output.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.progress.completedUnitCount -= lastKnownProgress.completed
                self.progress.totalUnitCount -= lastKnownProgress.total
                self.taskProgressCancellables[task] = nil

            } receiveValue: { _ in }
            .store(in: &self.taskProgressCancellables[task, default: []])
    }

    private func downloadTask(_ task: WebKitDownloadTask, withId identifier: UUID, completedWith result: Subscribers.Completion<FileDownloadError>) {
        dispatchPrecondition(condition: .onQueue(.main))

        updateItem(withId: identifier) { item in
            if case .failure(let error) = result {
                item?.error = error
            }
            item?.progress = nil
        }

        self.downloadTaskCancellables[task] = nil
    }

    private func updateItem(withId identifier: UUID, mutate: (inout DownloadListItem?) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))

        let original = self.items[identifier]
        var modified = original
        mutate(&modified)
        guard modified != original else { return }

        self.items[identifier] = modified

        switch (original, modified) {
        case (.none, .none):
            break
        case (.none, .some(let item)):
            self.updatesSubject.send((.added, item))
            store.save(item)
        case (.some, .some(let item)):
            self.updatesSubject.send((.updated, item))
            store.save(item)
        case (.some(let item), .none):
            self.updatesSubject.send((.removed, item))
            store.remove(item)
        }
    }

    private func downloadRestartedCallback(for item: DownloadListItem, webView: WKWebView) -> (WebKitDownload) -> Void {
        return { download in
            // Important: WebKitDownloadTask (as well as WKWebView) should be deallocated on the Main Thread
            dispatchPrecondition(condition: .onQueue(.main))
            withExtendedLifetime(webView) {
                guard let destinationURL = item.destinationURL else {
                    assertionFailure("trying to restart download with destinationURL not set")
                    return
                }

                let task = self.downloadManager.add(download, location: .preset(destinationURL: destinationURL, tempURL: item.tempURL))
                self.subscribeToDownloadTask(task, updating: item)
            }
        }
    }

    // MARK: interface

    var hasActiveDownloads: Bool {
        !downloadTaskCancellables.isEmpty
    }

    var mostRecentModification: Date? {
        return items.values.max { a, b in
            a.modified < b.modified
        }?.modified
    }

    func downloads<T: Comparable>(sortedBy keyPath: KeyPath<DownloadListItem, T>, ascending: Bool) -> [DownloadListItem] {
        dispatchPrecondition(condition: .onQueue(.main))
        let comparator: (T, T) -> Bool = ascending ? (<) : (>)
        return items.values.sorted(by: {
            comparator($0[keyPath: keyPath], $1[keyPath: keyPath])
        })
    }

    var updates: AnyPublisher<Update, Never> {
        return updatesSubject.eraseToAnyPublisher()
    }

    func restart(downloadWithIdentifier identifier: UUID) {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let item = items[identifier], let webView = self.webViewProvider() else { return }
        do {
            guard let resumeData = item.error?.resumeData,
                  let tempURL = item.tempURL,
                  FileManager.default.fileExists(atPath: tempURL.path),
                  item.destinationURL != nil
            else {
                struct ThrowableError: Error {}
                throw ThrowableError()
            }
            try webView.resumeDownload(from: resumeData,
                                       to: tempURL,
                                       completionHandler: self.downloadRestartedCallback(for: item, webView: webView))
        } catch {
            let request = item.createRequest()
            webView.startDownload(request, completionHandler: self.downloadRestartedCallback(for: item, webView: webView))
        }
    }

    func cleanupInactiveDownloads() {
        dispatchPrecondition(condition: .onQueue(.main))

        for (id, item) in self.items where item.progress == nil {
            self.items[id] = nil
            self.updatesSubject.send((.removed, item))
        }

        store.clear()
    }

    func cleanupInactiveDownloads(for domains: Set<String>) {
        for (id, item) in self.items where item.progress == nil {
            if domains.contains(item.websiteURL?.host ?? "") ||
                domains.contains(item.url.host ?? "") {
                self.items[id] = nil
                self.updatesSubject.send((.removed, item))
                store.remove(item)
            }
        }
    }

    func remove(downloadWithIdentifier identifier: UUID) {
        dispatchPrecondition(condition: .onQueue(.main))

        updateItem(withId: identifier) { item in
            item?.progress?.cancel()
            item = nil
        }
    }

    func cancel(downloadWithIdentifier identifier: UUID) {
        dispatchPrecondition(condition: .onQueue(.main))
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
                  url: task.originalRequest?.url ?? .blankPage,
                  websiteURL: task.originalRequest?.mainDocumentURL,
                  progress: task.progress,
                  destinationURL: nil,
                  tempURL: nil,
                  error: nil)
    }

    func createRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(websiteURL?.absoluteString, forHTTPHeaderField: URLRequest.HeaderKey.referer.rawValue)
        return request
    }

}
