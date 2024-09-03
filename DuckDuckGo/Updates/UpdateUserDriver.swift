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

protocol UpdateUserDriverDelegate: AnyObject {
    func userDriverUpdateCheckStart(_ userDriver: UpdateUserDriver)
    func userDriverUpdateCheckEnd(_ userDriver: UpdateUserDriver, item: SUAppcastItem?, isInstalled: Bool)
}

final class UpdateUserDriver: NSObject, SPUUserDriver {
    private var internalUserDecider: InternalUserDecider
    private var automaticUpdateFlow: Bool
    private weak var delegate: UpdateUserDriverDelegate?

    init(internalUserDecider: InternalUserDecider,
         automaticUpdateFlow: Bool,
         delegate: UpdateUserDriverDelegate? = nil) {
        self.internalUserDecider = internalUserDecider
        self.automaticUpdateFlow = automaticUpdateFlow
        self.delegate = delegate
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
        delegate?.userDriverUpdateCheckStart(self)
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState) async -> SPUUserUpdateChoice {
        guard !appcastItem.isInformationOnlyUpdate else {
            return .dismiss
        }

        Logger.updates.debug("Updater did find valid update: \(appcastItem.displayVersionString)(\(appcastItem.versionString))")

        PixelKit.fire(DebugEvent(GeneralPixel.updaterDidFindUpdate))

        if !automaticUpdateFlow {
            delegate?.userDriverUpdateCheckEnd(self, item: appcastItem, isInstalled: false)

            return .dismiss
        }

        return .install
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
    }

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {
    }

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        let item = (error as NSError).userInfo["SULatestAppcastItemFound"] as? SUAppcastItem
        Logger.updates.debug("Updater did not find update: \(String(describing: item?.displayVersionString))(\(String(describing: item?.versionString)))")
        if let item {
            // User is running the latest version
            delegate?.userDriverUpdateCheckEnd(self, item: item, isInstalled: true)
        }

        PixelKit.fire(DebugEvent(GeneralPixel.updaterDidNotFindUpdate, error: error))

        acknowledgement()
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        let megabytes = Double(expectedContentLength) / 1024
        print("[Update] Expected content length: \(String(format: "%.2f", megabytes)) MB")
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        let megabytes = Double(length) / 1024
        print("[Update] Did receive: \(String(format: "%.2f", megabytes)) MB")
    }

    func showDownloadDidStartExtractingUpdate() {
        print("[Update] Start extracting update")
    }

    func showExtractionReceivedProgress(_ progress: Double) {
        print("[Update] Extraction: \(String(format: "%.2f", progress / 100.0))%")
    }

    func showReadyToInstallAndRelaunch() async -> SPUUserUpdateChoice {
        .install
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        retryTerminatingApplication()
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func showUpdateInFocus() {
    }

    func dismissUpdateInstallation() {
    }
}

#endif
