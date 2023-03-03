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
    let url: URL
    let websiteURL: URL?

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

        var error: FileDownloadError? {
            guard case .failed(let error) = self else { return nil }
            return error
        }

        init(item: DownloadListItem) {
            if let progress = item.progress {
                self = .downloading(progress)
            } else if item.error == nil, let destinationURL = item.destinationURL {
                self = .complete(destinationURL)
            } else {
                self = .failed(item.error ?? .failedToCompleteDownloadTask(underlyingError: URLError(.cancelled), resumeData: nil))
            }
        }
    }
    @Published private(set) var state: State

    init(item: DownloadListItem) {
        self.id = item.identifier
        self.url = item.url
        self.websiteURL = item.websiteURL
        self.state = .init(item: item)

        self.update(with: item)
    }

    func update(with item: DownloadListItem) {
        self.localURL = item.destinationURL
        self.filename = item.destinationURL?.lastPathComponent ?? ""
        self.fileType = item.fileType
        self.state = .init(item: item)
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
