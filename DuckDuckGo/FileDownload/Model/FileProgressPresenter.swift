//
//  FileProgressPresenter.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

final class FileProgressPresenter {

    private var cancellables = Set<AnyCancellable>()
    private let progress: Progress
    private(set) var fileProgress: Progress? {
        willSet {
            fileProgress?.unpublish()
        }
    }

    init(progress: Progress) {
        self.progress = progress
    }

    /// display file fly-to-dock animation and download progress in Finder and Dock
    @MainActor func displayFileProgress(at url: URL?) {
        self.cancellables.removeAll(keepingCapacity: true)
        guard let url else {
            self.fileProgress = nil
            return
        }

        let fileProgress = Progress(copy: progress)
        fileProgress.fileURL = url
        fileProgress.cancellationHandler = { [progress] in
            progress.cancel()
        }
        // only display fly-to-dock animation only once - setting the original &progress.flyToImage to nil
        swap(&fileProgress.fileIconOriginalRect, &progress.fileIconOriginalRect)
        swap(&fileProgress.flyToImage, &progress.flyToImage)
        fileProgress.fileIcon = progress.fileIcon

        progress.publisher(for: \.totalUnitCount)
            .assign(to: \.totalUnitCount, onWeaklyHeld: fileProgress)
            .store(in: &cancellables)
        progress.publisher(for: \.completedUnitCount)
            .assign(to: \.completedUnitCount, onWeaklyHeld: fileProgress)
            .store(in: &cancellables)

        self.fileProgress = fileProgress
        fileProgress.publish()
    }

    deinit {
        fileProgress?.unpublish()
    }

}
