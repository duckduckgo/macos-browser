//
//  UpdateController.swift
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
import Sparkle
import BrowserServicesKit
import SwiftUIExtensions
import PixelKit
import SwiftUI

#if SPARKLE

final class UpdateController: NSObject {

    enum Constants {
        static let internalChannelName = "internal-channel"
    }

    lazy var notificationPresenter = UpdateNotificationPresenter()

    let willRelaunchAppPublisher: AnyPublisher<Void, Never>

    init(internalUserDecider: InternalUserDecider) {
        willRelaunchAppPublisher = willRelaunchAppSubject.eraseToAnyPublisher()
        self.internalUserDecider = internalUserDecider
        super.init()

        configureUpdater()
    }

    func checkForUpdates(_ sender: Any!) {
        if !SupportedOSChecker.isCurrentOSReceivingUpdates {
            showNotSupportedInfo()
        }

        NSApp.windows.forEach {
            if let controller = $0.windowController, "\(type(of: controller))" == "SUUpdateAlert" {
                $0.orderFrontRegardless()
                $0.makeKey()
                $0.makeMain()
            }
        }
        updater.checkForUpdates(sender)
    }

    var availableUpdate: Update? {
        didSet {
            if availableUpdate != nil {
                notificationPresenter.showUpdateNotification(icon: NSImage.updateNotificationInfo, text: "New version available. Relaunch to update.")
            }
        }
    }

    // MARK: - Private

    private var updater: SPUStandardUpdaterController!
    private let willRelaunchAppSubject = PassthroughSubject<Void, Never>()
    private var internalUserDecider: InternalUserDecider

    private var areAutomaticUpdatesEnabled: Bool {
        return true
    }

    private var isUpdateFound: Bool = false
    private var isUpdateDownloaded: Bool = false

    private func refreshUpdateObjectIfNeeded(appcastItem: SUAppcastItem) {
        if isUpdateFound && isUpdateDownloaded {
            availableUpdate = Update(appcastItem: appcastItem)
        } else {
            availableUpdate = nil
        }
    }

    private func configureUpdater() {
    // The default configuration of Sparkle updates is in Info.plist
    updater = SPUStandardUpdaterController(updaterDelegate: self, userDriverDelegate: self)

    //TODO: Uncomment
//#if DEBUG
//        updater.updater.automaticallyChecksForUpdates = false
//        updater.updater.updateCheckInterval = 0
//#endif

        updater.updater.automaticallyDownloadsUpdates = areAutomaticUpdatesEnabled
        updater.updater.checkForUpdatesInBackground()
    }

    private func showNotSupportedInfo() {
        if NSAlert.osNotSupported().runModal() != .cancel {
            let url = Preferences.UnsupportedDeviceInfoBox.softwareUpdateURL
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openUpdatesPage() {
        notificationPresenter.openUpdatesPage()
    }

    @objc func runUpdate() {
        restartApp()
    }

    private func restartApp() {
        guard let executablePath = Bundle.main.executablePath else {
            print("Unable to find executable path")
            return
        }

        let task = Process()
        task.launchPath = executablePath

        do {
            try task.run()
        } catch {
            print("Unable to launch the app: \(error)")
            return
        }

        // Terminate the current app instance
        exit(0)
    }
}

extension UpdateController: SPUStandardUserDriverDelegate {

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        return !areAutomaticUpdatesEnabled
    }

}

extension UpdateController: SPUUpdaterDelegate {

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        if internalUserDecider.isInternalUser {
            return Set([Constants.internalChannelName])
        } else {
            return Set()
        }
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        willRelaunchAppSubject.send()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let errorCode = (error as NSError).code
        guard ![Int(Sparkle.SUError.noUpdateError.rawValue),
                Int(Sparkle.SUError.installationCanceledError.rawValue),
                Int(Sparkle.SUError.runningTranslocated.rawValue)].contains(errorCode) else {
            return
        }

        PixelKit.fire(DebugEvent(GeneralPixel.updaterAborted, error: error))
    }

    func updater(_ updater: SPUUpdater,
                 userDidMake choice: SPUUserUpdateChoice,
                 forUpdate updateItem: SUAppcastItem,
                 state: SPUUserUpdateState) {
        switch choice {
        case .skip:
            PixelKit.fire(DebugEvent(GeneralPixel.userSelectedToSkipUpdate))
        case .install:
            PixelKit.fire(DebugEvent(GeneralPixel.userSelectedToInstallUpdate))
        case .dismiss:
            PixelKit.fire(DebugEvent(GeneralPixel.userSelectedToDismissUpdate))
        @unknown default:
            break
        }
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        isUpdateFound = true
        refreshUpdateObjectIfNeeded(appcastItem: item)
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        isUpdateDownloaded = true
        refreshUpdateObjectIfNeeded(appcastItem: item)
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {

    }

}

#endif
