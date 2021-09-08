//
//  DownloadViewModel.swift
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

final class DownloadViewModel {

    let id: UUID
    let added: Date
    var modified: Date

    let url: URL
    let websiteURL: URL?

    private(set) var tempURL: URL?
    @Published private(set) var localURL: URL? {
        didSet {
            self.filename = localURL?.lastPathComponent ?? ""
        }
    }
    @Published private(set) var filename: String = ""
    @Published private(set) var fileType: UTType?

    enum State {
        case downloading(Progress)
        case complete(URL?)
        case failed(FileDownloadError)

        var progress: Progress? {
            guard case .downloading(let progress) = self else { return nil }
            return progress
        }
    }
    @Published private(set) var state: State

    weak var task: WebKitDownloadTask? {
        didSet {
            webView = task?.originalWebView
            postflight = task?.postflight

            self.cancellables.removeAll()
            if let task = task {
                self.subscribe(to: task)
            }
        }
    }

    private(set) weak var webView: WKWebView?
    var postflight: FileDownloadManager.PostflightAction?

    private var cancellables = Set<AnyCancellable>()

    init(task: WebKitDownloadTask, added: Date) {
        self.id = UUID()
        self.added = added
        self.modified = added
        self.url = task.originalRequest?.url ?? .emptyPage
        self.websiteURL = task.originalRequest?.mainDocumentURL
        self.localURL = task.destinationURL
        self.tempURL = task.tempURL
        self.filename = task.destinationURL?.lastPathComponent ?? ""
        self.state = .downloading(task.progress)

        self.task = task
        self.webView = task.originalWebView
        self.postflight = task.postflight

        self.subscribe(to: task)
    }

    convenience init(task: WebKitDownloadTask) {
        self.init(task: task, added: Date())
    }

    init(entry: DownloadListItem) {
        self.id = entry.identifier
        self.url = entry.url
        self.websiteURL = entry.websiteURL
        self.localURL = entry.destinationURL
        self.tempURL = entry.tempURL
        self.filename = entry.destinationURL?.lastPathComponent ?? ""
        self.fileType = entry.fileType
        self.added = entry.added
        self.modified = entry.modified
        if entry.error == nil,
           let destinationURL = entry.destinationURL {
            self.state = .complete(destinationURL)
    } else {
            self.state = .failed(entry.error
                                    ?? .failedToCompleteDownloadTask(underlyingError: URLError(.cancelled), resumeData: nil))
        }
    }

    func createRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(websiteURL?.absoluteString, forHTTPHeaderField: URLRequest.HeaderKey.referer.rawValue)
        return request
    }

    private func subscribe(to task: WebKitDownloadTask) {
        self.state = .downloading(task.progress)

        task.output.sink { [weak self] completion in
            guard let self = self else { return }
            if case .failure(let error) = completion {
                self.state = .failed(error)
            } else {
                self.state = .complete(self.localURL)
            }
            self.task = nil

        } receiveValue: { [weak self] url in
            self?.localURL = url
        }.store(in: &cancellables)

        task.$destinationURL.filter { $0 != nil }
            .weakAssign(to: \.localURL, on: self)
            .store(in: &cancellables)
        task.$fileType.weakAssign(to: \.fileType, on: self).store(in: &cancellables)
        task.$tempURL.weakAssign(to: \.tempURL, on: self)
            .store(in: &cancellables)
    }

}

extension DownloadViewModel {
    
    var error: FileDownloadError? {
        guard case .failed(let error) = state else { return nil }
        return error
    }

    var isActive: Bool {
        if case .downloading = state { return true }
        return false
    }

}
