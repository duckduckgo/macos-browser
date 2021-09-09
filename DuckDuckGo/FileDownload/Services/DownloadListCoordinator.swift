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

import Foundation
import Combine
import os.log

final class DownloadListCoordinator {
    static let shared = DownloadListCoordinator()

    private let store: DownloadListStoring
    private let downloadManager: FileDownloadManager

    private var items = [UUID: DownloadListItem]()

    private var downloadsCancellable: AnyCancellable?
    private var downloadTaskCancellables = [WebKitDownloadTask: Set<AnyCancellable>]()

    enum UpdateKind {
        case added
        case removed
        case updated
    }
    typealias Update = (kind: UpdateKind, item: DownloadListItem)
    private let updatesSubject = PassthroughSubject<Update, Never>()

    init(store: DownloadListStoring = DownloadListStore(), downloadManager: FileDownloadManager = .shared) {
        self.store = store
        self.downloadManager = downloadManager

        load()
        subscribeToDownloadManager()
    }

    private func load() {
        store.fetch(clearingItemsOlderThan: Date().addingTimeInterval(-3600 * 48)) { [weak self] result in
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
    }

    private func addItemOrUpdateLocation(for initialItem: DownloadListItem, destinationURL: URL?, tempURL: URL?) {
        dispatchPrecondition(condition: .onQueue(.main))

        updateItem(withId: initialItem.identifier) { item in
            if item == nil { item = initialItem }
            item!.destinationURL = destinationURL
            item!.tempURL = tempURL
        }
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
        case (.some(let item), .none):
            self.updatesSubject.send((.removed, item))
            store.remove(item)
        case (.some, .some(let item)):
            self.updatesSubject.send((.updated, item))
            store.save(item)
        }
    }

    private func downloadRestartedCallback(for item: DownloadListItem, webView: WKWebView) -> (WebKitDownload) -> Void {
        return { download in
            dispatchPrecondition(condition: .onQueue(.main))
            withExtendedLifetime(webView) {
                let location: FileDownloadManager.DownloadLocationPreference
                if let destinationURL = item.destinationURL {
                    location = .preset(destinationURL: destinationURL, tempURL: item.tempURL)
                } else {
                    location = .prompt
                }

                let task = self.downloadManager.add(download, delegate: self, location: location, postflight: .none)
                self.subscribeToDownloadTask(task, updating: item)
            }
        }
    }

    // MARK: interface

    func downloads<T: Comparable>(sortedBy keyPath: KeyPath<DownloadListItem, T>, ascending: Bool) -> [DownloadListItem] {
        dispatchPrecondition(condition: .onQueue(.main))
        let comparator: (T, T) -> Bool = ascending ? (<) : (>)
        return items.values.sorted(by: {
            comparator($0[keyPath: keyPath], $1[keyPath: keyPath])
        })
    }

    func updates() -> AnyPublisher<Update, Never> {
        return updatesSubject.eraseToAnyPublisher()
    }

    func restart(downloadWithIdentifier identifier: UUID) {
        dispatchPrecondition(condition: .onQueue(.main))

        guard let item = items[identifier],
              let webView = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController
                .browserTabViewController.tabViewModel?.tab.webView
        else {
            assertionFailure("Restarting download without open windows is not supported or download does not exist")
            return
        }

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

extension DownloadListCoordinator: FileDownloadManagerDelegate {

    func chooseDestination(suggestedFilename: String?, directoryURL: URL?, fileTypes: [UTType], callback: @escaping (URL?, UTType?) -> Void) {
        // if download canceled/failed before the choice was made show a Save Panel
        if WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.browserTabViewController == nil {
            WindowsManager.openNewWindow()
        }
        guard let delegate = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.browserTabViewController else {
            assertionFailure("Expected to have an open window")
            callback(nil, nil)
            return
        }
        delegate.chooseDestination(suggestedFilename: suggestedFilename, directoryURL: directoryURL, fileTypes: fileTypes, callback: callback)
    }

    func fileIconFlyAnimationOriginalRect(for downloadTask: WebKitDownloadTask) -> NSRect? {
        return nil
    }

}

extension DownloadListItem {

    init(task: WebKitDownloadTask) {
        let now = Date()
        self.init(identifier: UUID(),
                  added: now,
                  modified: now,
                  url: task.originalRequest?.url ?? .emptyPage,
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
