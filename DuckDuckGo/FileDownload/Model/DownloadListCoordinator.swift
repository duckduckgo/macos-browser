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

final class DownloadListItem {

    enum State {
        case downloading(Progress)
        case complete(URL?)
        case failed(error: FileDownloadError, resumeData: Data?)

        var progress: Progress? {
            guard case .downloading(let progress) = self else { return nil }
            return progress
        }
    }
    let id: String = UUID().uuidString
    
    @Published var state: State
    var added: Date
    var updated: Date
    @Published private(set) var localURL: URL?
    @Published private(set) var filename: String
    @Published private(set) var fileType: UTType?

    weak var task: WebKitDownloadTask? {
        didSet {
            webView = task?.originalWebView
            postflight = task?.postflight
            if let task = task {
                self.subscribe(to: task)
            } else {
                self.cancellables.removeAll()
            }
        }
    }
    weak var webView: WKWebView?
    var postflight: FileDownloadManager.PostflightAction?

    private var cancellables = Set<AnyCancellable>()

    init(task: WebKitDownloadTask, added: Date) {
        self.state = .downloading(task.progress)
        self.added = added
        self.updated = added
        self.task = task
        self.webView = task.originalWebView
        self.postflight = task.postflight
        self.filename = ""

        self.subscribe(to: task)
    }

    convenience init(task: WebKitDownloadTask) {
        self.init(task: task, added: Date())
    }

    init(localURL: URL, fileType: UTType?, added: Date = Date(), updated: Date = Date()) {
        self.state = .complete(localURL)
        self.localURL = localURL
        self.filename = localURL.lastPathComponent
        self.fileType = fileType
        self.added = added
        self.updated = updated
    }

    func createRequest() -> URLRequest {
        fatalError()
    }

    private func subscribe(to task: WebKitDownloadTask) {
        self.state = .downloading(task.progress)

        task.output.sink { [weak self] completion in
            guard let self = self else { return }
            if case .failure(let error) = completion {
                self.state = .failed(error: error, resumeData: error.resumeData)
            } else {
                self.state = .complete(self.localURL)
            }
            // TODO: inform Coordinator about state change
            self.task = nil

        } receiveValue: { [weak self] url in
            self?.localURL = url
        }.store(in: &cancellables)
        task.$destinationURL.weakAssign(to: \.localURL, on: self).store(in: &cancellables)
        task.$destinationURL.combineLatest(task.$suggestedFilename).map {
            $0.0?.lastPathComponent ?? $0.1 ?? ""
        }.weakAssign(to: \.filename, on: self).store(in: &cancellables)
        task.$fileType.weakAssign(to: \.fileType, on: self).store(in: &cancellables)
    }

}

final class DownloadListCoordinator {
    static let shared = DownloadListCoordinator()

    private let store: Any?
    private let downloadManager: FileDownloadManager

    private var cancellable: AnyCancellable?

    private var knownDownloadTasks: Set<WebKitDownloadTask> = []
    private var isAddingDownload = false
    @PublishedAfter private(set) var downloads: [DownloadListItem] = []

    let progress = Progress()

    init(store: Any? = nil, downloadManager: FileDownloadManager = .shared) {
        self.store = store
        self.downloadManager = downloadManager

        load()
        subscribeToDownloadManager()
    }

    private func load() {
        downloads = []
    }

    private func subscribeToDownloadManager() {
        cancellable = downloadManager.$downloads.sink { [weak self] tasks in
            guard let self = self,
                  // restarted download will be reassigned to existing item
                  !self.isAddingDownload
            else { return }

            let added = tasks.subtracting(self.knownDownloadTasks)

            self.knownDownloadTasks = tasks
            self.addDownloadTasks(added)
        }
    }

    func addDownloadTasks(_ tasks: Set<WebKitDownloadTask>) {
        downloads.append(contentsOf: tasks.map(DownloadListItem.init(task:)))
    }

    func restartDownload(at index: Int) {
        let model = downloads[index]
        let request = model.createRequest()

        defer {

        }
        guard let webView = model.webView
            ?? WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.browserTabViewController.tabViewModel?.tab.webView
        else {
            assertionFailure("Restarting download without open windows is not supported")
            return
        }

        // TODO: resumeDownload with resumeData
        webView.startDownload(request) { download in
            self.isAddingDownload = true
            let task = self.downloadManager.add(download, delegate: model, promptForLocation: true, postflight: model.postflight)
            self.isAddingDownload = false

            withExtendedLifetime(webView) {
                model.task = task
            }
        }
    }

    func cleanupInactiveDownloads() {
        downloads.removeAll { $0.task == nil }
    }

    func removeDownload(at index: Int) {
        cancelDownload(at: index)
        downloads.remove(at: index)
    }

    func cancelDownload(at index: Int) {
        downloads[index].task?.cancel()
    }

}

extension DownloadListItem: FileDownloadManagerDelegate {

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
