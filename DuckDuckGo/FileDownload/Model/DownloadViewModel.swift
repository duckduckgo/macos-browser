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

import Combine
import Common
import Foundation
import UniformTypeIdentifiers
import os.log

final class DownloadViewModel {

    let id: UUID
    let url: URL
    let websiteURL: URL?

    @Published private(set) var localURL: URL?
    @Published private(set) var filename: String = ""
    private var cancellable: AnyCancellable?

    enum State: Equatable {
        case downloading(Progress, shouldAnimateOnAppear: Bool)
        case complete(URL?)
        case failed(FileDownloadError)

        var progress: Progress? {
            guard case .downloading(let progress, _) = self else { return nil }
            return progress
        }

        var error: FileDownloadError? {
            guard case .failed(let error) = self else { return nil }
            return error
        }

        var shouldAnimateOnAppear: Bool? {
            guard case .downloading(_, shouldAnimateOnAppear: let animate) = self else { return nil }
            return animate
        }

        init(item: DownloadListItem, shouldAnimateOnAppear: Bool) {
            if let progress = item.progress {
                self = .downloading(progress, shouldAnimateOnAppear: shouldAnimateOnAppear)
            } else if item.error == nil, let destinationURL = item.destinationURL, item.tempURL == nil {
                self = .complete(destinationURL)
            } else {
                self = .failed(item.error ?? .failedToCompleteDownloadTask(underlyingError: URLError(.cancelled),
                                                                           resumeData: nil,
                                                                           isRetryable: item.destinationURL != nil))
            }
        }
    }
    @Published private(set) var state: State

    init(item: DownloadListItem) {
        self.id = item.identifier
        self.url = item.downloadURL
        self.websiteURL = item.websiteURL
        self.state = .init(item: item, shouldAnimateOnAppear: true)

        self.update(with: item)
    }

    func update(with item: DownloadListItem) {
        self.localURL = item.tempURL == nil ? item.destinationURL : nil // only return destination file URL for completed downloads
        self.filename = item.fileName
        let oldState = self.state
        let newState = State(item: item, shouldAnimateOnAppear: state.shouldAnimateOnAppear ?? true)
        if oldState != newState {
            Logger.fileDownload.debug("DownloadViewModel: \(item.identifier.uuidString): \(oldState.debugDescription) ➡️ \(newState.debugDescription)")
            self.state = newState
        }
    }

    /// resets shouldAnimateOnAppear flag
    func didAppear() {
        if case .downloading(let progress, shouldAnimateOnAppear: true) = state {
            state = .downloading(progress, shouldAnimateOnAppear: false)
        }
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

extension DownloadViewModel.State: CustomDebugStringConvertible {

    var debugDescription: String {
        switch self {
        case .downloading(let progress, shouldAnimateOnAppear: true):
            ".downloading(\(progress.isIndeterminate ? -1 : progress.fractionCompleted), animateOnAppear: true)"
        case .downloading(let progress, shouldAnimateOnAppear: false):
            ".downloading(\(progress.isIndeterminate ? -1 : progress.fractionCompleted))"
        case .complete:
            ".complete"
        case .failed:
            ".failed"
        }
    }

}
