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
import os.log

#if SPARKLE

enum UpdateCycleProgress {
    case updateCycleNotStarted
    case updateCycleDidStart
    case updateFound(SUAppcastItem)
    case updateNotFound(SUAppcastItem, NSError)
    case downloadDidStart
    case downloading(UInt64, UInt64)
    case extractionDidStart
    case extracting(Double)
    case readyToInstallAndRelaunch
    case installationDidStart
    case installing
    case updateCycleDone

    static var `default` = UpdateCycleProgress.updateCycleNotStarted

    var isDone: Bool {
        switch self {
        case .updateCycleDone: return true
        default: return false
        }
    }
}

protocol UpdateUserDriverDelegate: AnyObject {
    func userDriverUpdateCycleProgress(_ userDriver: UpdateUserDriver, progress: UpdateCycleProgress)
}

final class UpdateUserDriver: NSObject, SPUUserDriver {
    private var internalUserDecider: InternalUserDecider
    private var deferInstallation: Bool
    private weak var delegate: UpdateUserDriverDelegate?

    private var bytesToDownload: UInt64 = 0
    private var bytesDownloaded: UInt64 = 0

    private var onManualInstall: () -> Void = {}

    init(internalUserDecider: InternalUserDecider,
         deferInstallation: Bool,
         delegate: UpdateUserDriverDelegate?) {
        self.internalUserDecider = internalUserDecider
        self.deferInstallation = deferInstallation
        self.delegate = delegate
    }

    func install() {
        onManualInstall()
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
        delegate?.userDriverUpdateCycleProgress(self, progress: .updateCycleDidStart)
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState) async -> SPUUserUpdateChoice {
        Logger.updates.debug("Updater did find valid update: \(appcastItem.displayVersionString)(\(appcastItem.versionString))")
        PixelKit.fire(DebugEvent(GeneralPixel.updaterDidFindUpdate))

        delegate?.userDriverUpdateCycleProgress(self, progress: .updateFound(appcastItem))

        return appcastItem.isInformationOnlyUpdate ? .dismiss : .install
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
        // no-op
    }

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {
        // no-op
    }

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        let nsError = error as NSError
        guard let item = nsError.userInfo["SULatestAppcastItemFound"] as? SUAppcastItem else {
            acknowledgement()
            return
        }

        Logger.updates.debug("Updater did not find update: \(String(describing: item.displayVersionString))(\(String(describing: item.versionString)))")
        PixelKit.fire(DebugEvent(GeneralPixel.updaterDidNotFindUpdate, error: error))

        delegate?.userDriverUpdateCycleProgress(self, progress: .updateNotFound(item, nsError))
        delegate?.userDriverUpdateCycleProgress(self, progress: .updateCycleDone)

        acknowledgement()
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        // no-op
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        delegate?.userDriverUpdateCycleProgress(self, progress: .downloadDidStart)
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
        delegate?.userDriverUpdateCycleProgress(self, progress: .downloading(bytesDownloaded, bytesToDownload))
    }

    func showDownloadDidStartExtractingUpdate() {
        delegate?.userDriverUpdateCycleProgress(self, progress: .extractionDidStart)
    }

    func showExtractionReceivedProgress(_ progress: Double) {
        delegate?.userDriverUpdateCycleProgress(self, progress: .extracting(progress))
    }

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        if deferInstallation {
            onManualInstall = { reply(.install) }
        } else {
            reply(.install)
        }

        delegate?.userDriverUpdateCycleProgress(self, progress: .updateCycleDone)
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        delegate?.userDriverUpdateCycleProgress(self, progress: .installationDidStart)
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        delegate?.userDriverUpdateCycleProgress(self, progress: .installing)
        acknowledgement()
    }

    func showUpdateInFocus() {
        // no-op
    }

    func dismissUpdateInstallation() {
        delegate?.userDriverUpdateCycleProgress(self, progress: .updateCycleDone)
    }
}

#endif
