//
//  DownloadProgress.swift
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
import Foundation
import Navigation

final class DownloadProgress: Progress {

    private enum Constants {
        /// delay before we start calculating the estimated time - because initially it‘s not reliable
        static let remainingDownloadTimeEstimationDelay: TimeInterval = 1
        /// this seems to be working…
        static let downloadSpeedSmoothingFactor = 0.1
    }

    private var unitsCompletedCancellable: AnyCancellable?

    init(download: WebKitDownload) {
        super.init(parent: nil, userInfo: nil)

        totalUnitCount = -1
        completedUnitCount = 0
        fileOperationKind = .downloading
        kind = .file
        fileDownloadingSourceURL = download.originalRequest?.url
        isCancellable = true

        guard let downloadProgress = (download as? ProgressReporting)?.progress else {
            assertionFailure("WKDownload expected to be ProgressReporting")
            return
        }

        // update the task progress, throughput and estimated time based on tatal&completed progress values of the download
        unitsCompletedCancellable = Publishers.CombineLatest(
            downloadProgress.publisher(for: \.totalUnitCount),
            downloadProgress.publisher(for: \.completedUnitCount)
        )
        .dropFirst()
        .sink { [weak self] (total, completed) in
            self?.updateProgress(withTotal: total, completed: completed)
        }
    }

    /// set totalUnitCount, completedUnitCount with updating startTime, throughput and estimated time remaining
    private func updateProgress(withTotal total: Int64, completed: Int64) {
        if totalUnitCount != total {
            totalUnitCount = total
        }
        completedUnitCount = completed
        guard completed > 0 else { return }
        guard let startTime else {
            // track start time from a first received byte (completed > 0)
            startTime = Date()
            return
        }

        let elapsedTime = Date().timeIntervalSince(startTime)
        // delay before we start calculating the estimated time - because initially it‘s not reliable
        guard elapsedTime > Constants.remainingDownloadTimeEstimationDelay else { return }

        // calculate instantaneous download speed
        var throughput = Double(completed) / elapsedTime

        // calculate the moving average of download speed
        if let oldThroughput = self.throughput.map(Double.init) {
            throughput = Constants.downloadSpeedSmoothingFactor * throughput + (1 - Constants.downloadSpeedSmoothingFactor) * oldThroughput
        }
        self.throughput = Int(throughput)

        if total > 0 {
            self.estimatedTimeRemaining = Double(total - completed) / Double(throughput)
        }
    }

}
