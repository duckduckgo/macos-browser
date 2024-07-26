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

    init(internalUserDecider: InternalUserDecider,
         appRestarter: AppRestarting = AppRestarter()) {
        willRelaunchAppPublisher = willRelaunchAppSubject.eraseToAnyPublisher()
        self.internalUserDecider = internalUserDecider
        self.appRestarter = appRestarter
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
        updater.updater.lastUpdateCheckDate
    }

    @UserDefaultsWrapper(key: .automaticUpdates, defaultValue: true)
    var areAutomaticUpdatesEnabled: Bool {
        didSet {
            os_log("areAutomaticUpdatesEnabled: \(areAutomaticUpdatesEnabled)", log: .updates)
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

    private(set) var updater: SPUStandardUpdaterController!
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
        os_log("Checking for updates", log: .updates)

        updater.updater.checkForUpdates()
    }

    func checkForUpdateInBackground() {
        os_log("Checking for updates in background", log: .updates)

        updater.updater.checkForUpdatesInBackground()
    }

    // MARK: - Private

    private func configureUpdater() {
        // The default configuration of Sparkle updates is in Info.plist
        updater = SPUStandardUpdaterController(updaterDelegate: self, userDriverDelegate: self)
        shouldShowManualUpdateDialog = false

        if updater.updater.automaticallyDownloadsUpdates != areAutomaticUpdatesEnabled {
            updater.updater.automaticallyDownloadsUpdates = areAutomaticUpdatesEnabled
        }

#if DEBUG
        updater.updater.automaticallyChecksForUpdates = false
        updater.updater.automaticallyDownloadsUpdates = false
        updater.updater.updateCheckInterval = 0
#endif

        checkForUpdateInBackground()
    }

    @objc func openUpdatesPage() {
        notificationPresenter.openUpdatesPage()
    }

    @objc func runUpdate() {
        PixelKit.fire(DebugEvent(GeneralPixel.updaterDidRunUpdate))

        if areAutomaticUpdatesEnabled {
            appRestarter.restart()
        } else {
            updater.userDriver.activeUpdateAlert?.hideUnnecessaryUpdateButtons()
            shouldShowManualUpdateDialog = true
            checkForUpdate()
        }
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
        os_log("Updater started performing the update check. (isInternalUser: \(internalUserDecider.isInternalUser)", log: .updates)

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
        os_log("Updater did abort with error: \(error.localizedDescription)", log: .updates)

        let errorCode = (error as NSError).code
        guard ![Int(Sparkle.SUError.noUpdateError.rawValue),
                Int(Sparkle.SUError.installationCanceledError.rawValue),
                Int(Sparkle.SUError.runningTranslocated.rawValue)].contains(errorCode) else {
            return
        }

        PixelKit.fire(DebugEvent(GeneralPixel.updaterAborted, error: error))
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        os_log("Updater did find valid update: \(item.displayVersionString)(\(item.versionString))", log: .updates)

        guard !areAutomaticUpdatesEnabled else {
            // If automatic updates are enabled, we are waiting until the update is downloaded
            return
        }
        // For manual updates, show the available update without downloading
        onUpdateCheckEnd(item: item, isInstalled: false)

        PixelKit.fire(DebugEvent(GeneralPixel.updaterDidFindUpdate))
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        let item = (error as NSError).userInfo["SULatestAppcastItemFound"] as? SUAppcastItem
        os_log("Updater did not find update: \(String(describing: item?.displayVersionString))(\(String(describing: item?.versionString)))", log: .updates)

        onUpdateCheckEnd(item: item, isInstalled: true)

        PixelKit.fire(DebugEvent(GeneralPixel.updaterDidNotFindUpdate, error: error))
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        os_log("Updater did download update: \(item.displayVersionString)(\(item.versionString))", log: .updates)

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
        isUpdateBeingLoaded = false
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        os_log("Updater did finish update cycle", log: .updates)
    }

}

#endif
