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

protocol UpdateControllerProtocol: AnyObject {

    var latestUpdate: Update? { get }
    var latestUpdatePublisher: Published<Update?>.Publisher { get }

    var isUpdateAvailableToInstall: Bool { get }
    var isUpdateAvailableToInstallPublisher: Published<Bool>.Publisher { get }

    var isUpdateBeingLoaded: Bool { get }
    var isUpdateBeingLoadedPublisher: Published<Bool>.Publisher { get }

    var lastUpdateCheckDate: Date? { get }

    func checkForUpdate()
    func checkForUpdateInBackground()

    func runUpdate()

    var areAutomaticUpdatesEnabled: Bool { get set }

}

#if SPARKLE

final class UpdateController: NSObject, UpdateControllerProtocol {

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

    @Published private(set) var isUpdateBeingLoaded = false
    var isUpdateBeingLoadedPublisher: Published<Bool>.Publisher { $isUpdateBeingLoaded }

    @Published private(set) var latestUpdate: Update? {
        didSet {
            if let latestUpdate, !latestUpdate.isInstalled {
                switch latestUpdate.type {
                case .critical:
                    notificationPresenter.showUpdateNotification(icon: NSImage.criticalUpdateNotificationInfo, text: "Critical update required. Restart to update.")
                case .regular:
                    notificationPresenter.showUpdateNotification(icon: NSImage.updateNotificationInfo, text: "New version available. Restart to update.")
                }
                isUpdateAvailableToInstall = !latestUpdate.isInstalled
            } else {
                isUpdateAvailableToInstall = false
            }
        }
    }

    var latestUpdatePublisher: Published<Update?>.Publisher { $latestUpdate }

    @Published private(set) var isUpdateAvailableToInstall = false
    var isUpdateAvailableToInstallPublisher: Published<Bool>.Publisher { $isUpdateAvailableToInstall }

    var lastUpdateCheckDate: Date? {
        updater.updater.lastUpdateCheckDate
    }

    @UserDefaultsWrapper(key: .automaticUpdates, defaultValue: true)
    var areAutomaticUpdatesEnabled: Bool {
        didSet {
            if updater.updater.automaticallyDownloadsUpdates != areAutomaticUpdatesEnabled {
                updater.updater.automaticallyDownloadsUpdates = areAutomaticUpdatesEnabled

                // Reinitialize in order to reset the current loaded state
                if !areAutomaticUpdatesEnabled {
                    configureUpdater()
                    latestUpdate = nil
                }
            }
        }
    }

    var shouldShowManualUpdateDialog = false

    // MARK: - Public

    func checkNewApplicationVersion() {
        let updateStatus = UpdateDetector.isApplicationUpdated()
        switch updateStatus {
        case .noChange: break
        case .updated:
            notificationPresenter.showUpdateNotification(icon: NSImage.updateNotificationInfo, text: "Browser Updated")
        case .downgraded:
            notificationPresenter.showUpdateNotification(icon: NSImage.updateNotificationInfo, text: "Browser Downgraded")
        }
    }

    func checkForUpdate() {
        updater.updater.checkForUpdates()
    }

    func checkForUpdateInBackground() {
        updater.updater.checkForUpdatesInBackground()
    }

    // MARK: - Private

    private(set) var updater: SPUStandardUpdaterController!
    private let willRelaunchAppSubject = PassthroughSubject<Void, Never>()
    private var internalUserDecider: InternalUserDecider

    private func configureUpdater() {
        // The default configuration of Sparkle updates is in Info.plist
        updater = SPUStandardUpdaterController(updaterDelegate: self, userDriverDelegate: self)
        shouldShowManualUpdateDialog = false

    //TODO: Uncomment
//#if DEBUG
//        updater.updater.automaticallyChecksForUpdates = false
//        updater.updater.updateCheckInterval = 0
//#endif

        if updater.updater.automaticallyDownloadsUpdates != areAutomaticUpdatesEnabled {
            updater.updater.automaticallyDownloadsUpdates = areAutomaticUpdatesEnabled
        }

        checkForUpdateInBackground()
    }

    @objc func openUpdatesPage() {
        notificationPresenter.openUpdatesPage()
    }

    @objc func runUpdate() {
        if areAutomaticUpdatesEnabled {
            restartApp()
        } else {
            shouldShowManualUpdateDialog = true
            checkForUpdate()
        }
    }

    //TODO: Refactor to AppRestarter

    func restartApp() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let destinationPath = Bundle.main.bundlePath
        let quotedDestinationPath = shellQuotedString(destinationPath)

        let preOpenCmd = "/usr/bin/xattr -d -r com.apple.quarantine \(quotedDestinationPath)"

        let script = """
        (while /bin/kill -0 \(pid) >&/dev/null; do /bin/sleep 0.1; done; \(preOpenCmd); /usr/bin/open \(quotedDestinationPath)) &
        """

        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", script]

        do {
            try task.run()
        } catch {
            print("Unable to launch the task: \(error)")
            return
        }

        // Terminate the current app instance
        exit(0)
    }

    func shellQuotedString(_ string: String) -> String {
        let escapedString = string.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escapedString)'"
    }
}

extension UpdateController: SPUStandardUserDriverDelegate {

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        return shouldShowManualUpdateDialog
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {}

}

extension UpdateController: SPUUpdaterDelegate {

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        onUpdateCheckStart()
    }

    private func onUpdateCheckStart() {
        isUpdateBeingLoaded = true
    }

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
        guard !areAutomaticUpdatesEnabled else {
            // If automatic updates are enabled, we are waiting until the update is downloaded
            return
        }
        // For manual updates, show the available update without downloading
        onUpdateCheckEnd(item: item, isInstalled: false)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        let item = (error as NSError).userInfo["SULatestAppcastItemFound"] as? SUAppcastItem
        onUpdateCheckEnd(item: item, isInstalled: true)
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        guard areAutomaticUpdatesEnabled else {
            // If manual are enabled, we don't download
            return
        }
        // Automatic updates present the available update after it's downloaded
        onUpdateCheckEnd(item: item, isInstalled: false)
    }

    private func onUpdateCheckEnd(item: SUAppcastItem?, isInstalled: Bool) {
        if let item {
            latestUpdate = Update(appcastItem: item, isInstalled: isInstalled)
        } else {
            latestUpdate = nil
        }
        isUpdateBeingLoaded = false
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        print("")
    }

}

#endif
