//
//  UpdateUserDriver.swift
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

import Foundation
import Sparkle
import PixelKit
import BrowserServicesKit
import Combine
import os.log

#if SPARKLE

enum UpdateCycleProgress {
    case updateCycleNotStarted
    case updateCycleDidStart
    case updateCycleDone
    case downloadDidStart
    case downloading(Double)
    case extractionDidStart
    case extracting(Double)
    case readyToInstallAndRelaunch
    case installationDidStart
    case installing
    case updaterError(Error)

    static var `default` = UpdateCycleProgress.updateCycleNotStarted

    var isDone: Bool {
        switch self {
        case .updateCycleDone: return true
        default: return false
        }
    }

    var isIdle: Bool {
        switch self {
        case .updateCycleDone, .updateCycleNotStarted, .updaterError: return true
        default: return false
        }
    }

    var isFailed: Bool {
        switch self {
        case .updaterError: return true
        default: return false
        }
    }
}

final class UpdateUserDriver: NSObject, SPUUserDriver {
    enum Checkpoint: Equatable {
        case download
        case restart
    }

    private var internalUserDecider: InternalUserDecider

    private var checkpoint: Checkpoint
    private var onResuming: () -> Void = {}

    private var onSkipping: () -> Void = {}

    private var bytesToDownload: UInt64 = 0
    private var bytesDownloaded: UInt64 = 0

    @Published var updateProgress = UpdateCycleProgress.default
    public var updateProgressPublisher: Published<UpdateCycleProgress>.Publisher { $updateProgress }

    init(internalUserDecider: InternalUserDecider,
         areAutomaticUpdatesEnabled: Bool) {
        self.internalUserDecider = internalUserDecider
        self.checkpoint = areAutomaticUpdatesEnabled ? .restart : .download
    }

    func resume() {
        onResuming()
    }

    func cancelAndDismissCurrentUpdate() {
        onSkipping()
    }

    func show(_ request: SPUUpdatePermissionRequest) async -> SUUpdatePermissionResponse {
#if DEBUG
        .init(automaticUpdateChecks: false, sendSystemProfile: false)
#else
        .init(automaticUpdateChecks: true, sendSystemProfile: false)
#endif
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        Logger.updates.debug("Updater started performing the update check. (isInternalUser: \(self.internalUserDecider.isInternalUser)")
        updateProgress = .updateCycleDidStart
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        if appcastItem.isInformationOnlyUpdate {
            reply(.dismiss)
        }

        onSkipping = { reply(.skip) }

        if checkpoint == .download {
            onResuming = { reply(.install) }
            updateProgress = .updateCycleDone
        } else {
            reply(.install)
        }
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
        // no-op
    }

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {
        // no-op
    }

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        updateProgress = .updaterError(error)
        acknowledgement()
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        updateProgress = .downloadDidStart
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        bytesDownloaded = 0
        bytesToDownload = expectedContentLength
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        bytesDownloaded += length
        if bytesDownloaded > bytesToDownload {
            bytesToDownload = bytesDownloaded
        }
        updateProgress = .downloading(Double(bytesDownloaded) / Double(bytesToDownload))
    }

    func showDownloadDidStartExtractingUpdate() {
        updateProgress = .extractionDidStart
    }

    func showExtractionReceivedProgress(_ progress: Double) {
        updateProgress = .extracting(progress)
    }

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        onSkipping = { reply(.skip) }

        if checkpoint == .restart {
            onResuming = { reply(.install) }
        } else {
            reply(.install)
        }

        updateProgress = .updateCycleDone
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        updateProgress = .installationDidStart
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        updateProgress = .installing
        acknowledgement()
    }

    func showUpdateInFocus() {
        // no-op
    }

    func dismissUpdateInstallation() {
        guard !updateProgress.isFailed else { return }
        updateProgress = .updateCycleDone
    }
}

#endif
