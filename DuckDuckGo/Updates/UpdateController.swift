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
import Common
import Combine
import Sparkle
import BrowserServicesKit
import SwiftUIExtensions
import PixelKit
import SwiftUI
import os.log

enum UpdateControllerProgress {
    case idle
    case checkDidStart
    case downloadDidStart
    case downloading(UInt64, UInt64)
    case extractionDidStart
    case extracting(Double)
    case readyToInstallAndRelaunch
    case installationDidStart
    case installing
    case done

    static var `default` = UpdateControllerProgress.idle

    var isIdle: Bool {
        switch self {
        case .idle, .done: return true
        default: return false
        }
    }
}

protocol UpdateControllerProtocol: AnyObject {

    var latestUpdate: Update? { get }
    var latestUpdatePublisher: Published<Update?>.Publisher { get }

    var isUpdateAvailableToInstall: Bool { get }
    var isUpdateAvailableToInstallPublisher: Published<Bool>.Publisher { get }

    var updateProgress: UpdateControllerProgress { get }
    var updateProgressPublisher: Published<UpdateControllerProgress>.Publisher { get }

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

    init(internalUserDecider: InternalUserDecider,
         appRestarter: AppRestarting = AppRestarter()) {
        willRelaunchAppPublisher = willRelaunchAppSubject.eraseToAnyPublisher()
        self.internalUserDecider = internalUserDecider
        self.appRestarter = appRestarter
        super.init()

        configureUpdater()
    }

    @Published private(set) var updateProgress = UpdateControllerProgress.default
    var updateProgressPublisher: Published<UpdateControllerProgress>.Publisher { $updateProgress }

    @Published private(set) var latestUpdate: Update? {
        didSet {
            if let latestUpdate, !latestUpdate.isInstalled {
                switch latestUpdate.type {
                case .critical:
                    notificationPresenter.showUpdateNotification(icon: NSImage.criticalUpdateNotificationInfo, text: UserText.criticalUpdateNotification, presentMultiline: true)
                case .regular:
                    notificationPresenter.showUpdateNotification(icon: NSImage.updateNotificationInfo, text: UserText.updateAvailableNotification, presentMultiline: true)
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
        updater.lastUpdateCheckDate
    }

    @UserDefaultsWrapper(key: .automaticUpdates, defaultValue: true)
    var areAutomaticUpdatesEnabled: Bool {
        didSet {
            Logger.updates.debug("areAutomaticUpdatesEnabled: \(self.areAutomaticUpdatesEnabled)")
            if updater.automaticallyDownloadsUpdates != areAutomaticUpdatesEnabled {
                updater.automaticallyDownloadsUpdates = areAutomaticUpdatesEnabled

                // Reinitialize in order to reset the current loaded state
                if !areAutomaticUpdatesEnabled {
                    configureUpdater()
                    latestUpdate = nil
                }
            }
        }
    }

    var shouldShowManualUpdateDialog = false

    private(set) var updater: SPUUpdater!
    private(set) var userDriver: UpdateUserDriver!
    private var appRestarter: AppRestarting
    private let willRelaunchAppSubject = PassthroughSubject<Void, Never>()
    private var internalUserDecider: InternalUserDecider

    // MARK: - Public

    func checkNewApplicationVersion() {
        let updateStatus = ApplicationUpdateDetector.isApplicationUpdated()
        switch updateStatus {
        case .noChange: break
        case .updated:
            notificationPresenter.showUpdateNotification(icon: NSImage.successCheckmark, text: UserText.browserUpdatedNotification, buttonText: UserText.viewDetails)
        case .downgraded:
            notificationPresenter.showUpdateNotification(icon: NSImage.successCheckmark, text: UserText.browserDowngradedNotification, buttonText: UserText.viewDetails)
        }
    }

    func checkForUpdate() {
        Logger.updates.debug("Checking for updates")

        updater.checkForUpdates()
    }

    func checkForUpdateInBackground() {
        Logger.updates.debug("Checking for updates in background")

        updater.checkForUpdatesInBackground()
    }

    // MARK: - Private

    private func configureUpdater() {
        // The default configuration of Sparkle updates is in Info.plist
        userDriver = UpdateUserDriver(internalUserDecider: internalUserDecider,
                                      deferInstallation: !areAutomaticUpdatesEnabled,
                                      delegate: self)
        updater = SPUUpdater(hostBundle: Bundle.main, applicationBundle: Bundle.main, userDriver: userDriver, delegate: self)
        try? updater.start()
        shouldShowManualUpdateDialog = false

        if updater.automaticallyDownloadsUpdates != areAutomaticUpdatesEnabled {
            updater.automaticallyDownloadsUpdates = areAutomaticUpdatesEnabled
        }

#if DEBUG
//        updater.automaticallyChecksForUpdates = false
//        updater.automaticallyDownloadsUpdates = false
//        updater.updateCheckInterval = 0
#endif

//        checkForUpdateInBackground()
    }

    @objc func openUpdatesPage() {
        notificationPresenter.openUpdatesPage()
    }

    @objc func runUpdate() {
        PixelKit.fire(DebugEvent(GeneralPixel.updaterDidRunUpdate))

        if areAutomaticUpdatesEnabled {
            appRestarter.restart()
        } else {
//            updater.userDriver.activeUpdateAlert?.hideUnnecessaryUpdateButtons()
            shouldShowManualUpdateDialog = true
            checkForUpdate()
        }
    }

}

//extension UpdateController: SPUStandardUserDriverDelegate {
//
//    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
//        return shouldShowManualUpdateDialog
//    }
//
//    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {}
//
//}

extension UpdateController: UpdateUserDriverDelegate {
    func userDriverUpdateCheckEnd(_ userDriver: UpdateUserDriver, item: SUAppcastItem?, isInstalled: Bool) {
        onUpdateCheckEnd(item: item, isInstalled: isInstalled)
    }

    func userDriverUpdateCheckProgress(_ userDriver: UpdateUserDriver, progress: UpdateControllerProgress) {
        updateProgress = progress
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
        Logger.updates.error("Updater did abort with error: \(error.localizedDescription)")
        let errorCode = (error as NSError).code
        guard ![Int(Sparkle.SUError.noUpdateError.rawValue),
                Int(Sparkle.SUError.installationCanceledError.rawValue),
                Int(Sparkle.SUError.runningTranslocated.rawValue),
                Int(Sparkle.SUError.downloadError.rawValue)].contains(errorCode) else {
            return
        }

        PixelKit.fire(DebugEvent(GeneralPixel.updaterAborted, error: error))
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        Logger.updates.debug("Updater did download update: \(item.displayVersionString)(\(item.versionString))")

        guard areAutomaticUpdatesEnabled else {
            // If manual are enabled, we don't download
            return
        }
        // Automatic updates present the available update after it's downloaded
        onUpdateCheckEnd(item: item, isInstalled: false)

        PixelKit.fire(DebugEvent(GeneralPixel.updaterDidDownloadUpdate))
    }

    private func onUpdateCheckEnd(item: SUAppcastItem?, isInstalled: Bool) {
        if let item {
            latestUpdate = Update(appcastItem: item, isInstalled: isInstalled)
        } else {
            latestUpdate = nil
        }
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        Logger.updates.debug("Updater did finish update cycle")
        updateProgress = .done
    }

}

#endif
