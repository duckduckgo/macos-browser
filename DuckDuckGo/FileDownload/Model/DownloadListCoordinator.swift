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
    private let queue = DispatchQueue.init(label: "downloads.coordinator.queue")

    private var cancellable: AnyCancellable?

    private var downloadTaskCancellables: [WebKitDownloadTask: Set<AnyCancellable>] = [:]
    @PublishedAfter private(set) var downloads: [DownloadViewModel] = []
    private var downloadEntries = [WebKitDownloadTask: DownloadListItem]()

    let progress = Progress()

    init(store: DownloadListStoring = DownloadListStore(), downloadManager: FileDownloadManager = .shared) {
        self.store = store
        self.downloadManager = downloadManager

        load()
        subscribeToDownloadManager()
    }

    private func load() {
        downloads = []
        store.fetch(clearingItemsOlderThan: .monthAgo) { [weak self] result in
            switch result {
            case .success(let entries):
                self?.downloads.append(contentsOf: entries.map(DownloadViewModel.init(entry:)))
            case .failure(let error):
                os_log("Cleaning and loading of downloads failed: %s", log: .history, type: .error, error.localizedDescription)
            }
        }
    }

    private func subscribeToDownloadManager() {
        cancellable = downloadManager.$downloads.receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                guard let self = self else { return }

                let added = tasks.subtracting(self.downloadTaskCancellables.keys)
                added.forEach(self.subscribeToDownloadTask)
                added.forEach(self.subscribeToDownloadTaskCompletion)
        }
    }

    private func updateDownloadHistoryEntryIfNeeded(for task: WebKitDownloadTask,
                                                    model: DownloadViewModel? = nil,
                                                    error: FileDownloadError? = nil) {
        var updated = false
        var entry: DownloadListItem! = self.downloadEntries[task]

        if entry == nil {
            var model: DownloadViewModel! = model
            if model == nil {
                model = DownloadViewModel(task: task)
                self.downloads.insert(model, at: 0)
            }
            entry = DownloadListItem(model)
            updated = true
        }

        if entry.fileType != task.fileType {
            entry.fileType = task.fileType
            updated = true
        }
        if entry.destinationURL != task.destinationURL {
            entry.destinationURL = task.destinationURL
            updated = true
        }
        if entry.tempURL != task.tempURL {
            entry.tempURL = task.tempURL
            updated = true
        }
        
        if let error = error {
            entry.error = error
            updated = true
        }

        if updated {
            self.downloadEntries[task] = entry
            self.store.save(entry)
        }
    }

    private func subscribeToDownloadTask(_ task: WebKitDownloadTask) {
        task.$destinationURL.asVoid()
            .merge(with: task.$tempURL.asVoid())
            .merge(with: task.$fileType.asVoid())
            .merge(with: task.progress.publisher(for: \.fractionCompleted).asVoid())
            .throttle(for: 0.3, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.updateDownloadHistoryEntryIfNeeded(for: task)
            }
            .store(in: &self.downloadTaskCancellables[task, default: []])
    }

    private func subscribeToDownloadTaskCompletion(_ task: WebKitDownloadTask) {
        // clear download cancellables (and the task as a Key) when download completes
        task.output
            .sink { [weak self] completion in
                guard let self = self else { return }
                if case .failure(let error) = completion {
                    self.updateDownloadHistoryEntryIfNeeded(for: task, error: error)
                }
                self.downloadTaskCancellables[task] = nil
                self.downloadEntries[task] = nil

            } receiveValue: { [weak self] _ in
                self?.updateDownloadHistoryEntryIfNeeded(for: task)
            }
            .store(in: &self.downloadTaskCancellables[task, default: []])
    }

    private func downloadRestartedCallback(for model: DownloadViewModel, webView: WKWebView) -> (WebKitDownload) -> Void {
        return { download in
            withExtendedLifetime(webView) {
                let task = self.downloadManager.add(download,
                                                    delegate: model,
                                                    promptForLocation: true,
                                                    postflight: model.postflight)
                self.subscribeToDownloadTaskCompletion(task)
                if let tempURL = model.tempURL, task.tempURL == nil {
                    task.tempURL = tempURL
                }
                if let destinationURL = model.localURL, task.destinationURL == nil {
                    task.destinationURL = destinationURL
                }

                model.task = task
                let entry = DownloadListItem(model)
                self.downloadEntries[task] = entry
                self.store.save(entry)
            }
        }
    }

    // MARK: interface

    func restartDownload(at index: Int) {
        let model = downloads[index]

        guard let webView = model.webView
                ?? WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.browserTabViewController
                .tabViewModel?.tab.webView
        else {
            assertionFailure("Restarting download without open windows is not supported")
            return
        }

        do {
            guard let resumeData = model.error?.resumeData,
                  let tempURL = model.tempURL,
                  FileManager.default.fileExists(atPath: tempURL.path),
                  model.localURL != nil
            else {
                struct ThrowableError: Error {}
                throw ThrowableError()
            }
            try webView.resumeDownload(from: resumeData,
                                       to: tempURL,
                                       completionHandler: self.downloadRestartedCallback(for: model, webView: webView))
        } catch {
            let request = model.createRequest()
            webView.startDownload(request, completionHandler: self.downloadRestartedCallback(for: model,
                                                                                             webView: webView))
        }
    }

    func cleanupInactiveDownloads() {
        downloads.removeAll { $0.task == nil }
        store.clear()
    }

    func removeDownload(at index: Int) {
        cancelDownload(at: index)
        downloads.remove(at: index)
    }

    func cancelDownload(at index: Int) {
        downloads[index].task?.cancel()
    }

    func sync() {
        store.sync()
    }

}

extension DownloadViewModel: FileDownloadManagerDelegate {

    func chooseDestination(suggestedFilename: String?, directoryURL: URL?, fileTypes: [UTType], callback: @escaping (URL?, UTType?) -> Void) {
        if let url = self.localURL {
            callback(url, nil)
            return
        }

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

    init(_ item: DownloadViewModel) {
        self.init(identifier: item.id,
                  added: item.added,
                  modified: item.modified,
                  url: item.url,
                  websiteURL: item.websiteURL,
                  destinationURL: item.localURL,
                  tempURL: item.tempURL,
                  error: item.error)
    }

}
