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

    @Published private(set) var isUpdateBeingLoaded = false
    var isUpdateBeingLoadedPublisher: Published<Bool>.Publisher { $isUpdateBeingLoaded }

    // Struct used to cache data until the updater finishes checking for updates
    struct UpdateCheckResult {
        let item: SUAppcastItem
        let isInstalled: Bool
    }
    private var updateCheckResult: UpdateCheckResult?

    @Published private(set) var latestUpdate: Update? {
        didSet {
            if let latestUpdate, !latestUpdate.isInstalled {
                if !shouldShowManualUpdateDialog {
                    switch latestUpdate.type {
                    case .critical:
                        notificationPresenter.showUpdateNotification(icon: NSImage.criticalUpdateNotificationInfo, text: UserText.criticalUpdateNotification, presentMultiline: true)
                    case .regular:
                        notificationPresenter.showUpdateNotification(icon: NSImage.updateNotificationInfo, text: UserText.updateAvailableNotification, presentMultiline: true)
                    }
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
            Logger.updates.debug("areAutomaticUpdatesEnabled: \(self.areAutomaticUpdatesEnabled)")
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

    var automaticUpdateFlow: Bool {
        // In case the current user is not the owner of the binary, we have to switch
        // to manual update flow because the authentication is required.
        return areAutomaticUpdatesEnabled && binaryOwnershipChecker.isCurrentUserOwner()
    }

    var shouldShowManualUpdateDialog = false

    private(set) var updater: SPUStandardUpdaterController!
    private var appRestarter: AppRestarting
    private let willRelaunchAppSubject = PassthroughSubject<Void, Never>()
    private var internalUserDecider: InternalUserDecider
    private let binaryOwnershipChecker: BinaryOwnershipChecking

    // MARK: - Public

    init(internalUserDecider: InternalUserDecider,
         appRestarter: AppRestarting = AppRestarter(),
         binaryOwnershipChecker: BinaryOwnershipChecking = BinaryOwnershipChecker()) {
        willRelaunchAppPublisher = willRelaunchAppSubject.eraseToAnyPublisher()
        self.internalUserDecider = internalUserDecider
        self.appRestarter = appRestarter
        self.binaryOwnershipChecker = binaryOwnershipChecker
        super.init()

        configureUpdater()
    }

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

        updater.updater.checkForUpdates()
    }

    func checkForUpdateInBackground() {
        Logger.updates.debug("Checking for updates in background")

        updater.updater.checkForUpdatesInBackground()
    }

    @objc func runUpdate() {
        PixelKit.fire(DebugEvent(GeneralPixel.updaterDidRunUpdate))

        if automaticUpdateFlow {
            appRestarter.restart()
        } else {
            updater.userDriver.activeUpdateAlert?.hideUnnecessaryUpdateButtons()
            shouldShowManualUpdateDialog = true
            checkForUpdate()
        }
    }

    // MARK: - Private

    private func configureUpdater() {
        // The default configuration of Sparkle updates is in Info.plist
        updater = SPUStandardUpdaterController(updaterDelegate: self, userDriverDelegate: self)
        shouldShowManualUpdateDialog = false

        if updater.updater.automaticallyDownloadsUpdates != automaticUpdateFlow {
            updater.updater.automaticallyDownloadsUpdates = automaticUpdateFlow
        }

#if DEBUG
        updater.updater.automaticallyChecksForUpdates = false
        updater.updater.automaticallyDownloadsUpdates = false
        updater.updater.updateCheckInterval = 0
#endif
    }

    @objc private func openUpdatesPage() {
        notificationPresenter.openUpdatesPage()
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
        Logger.updates.debug("Updater started performing the update check. (isInternalUser: \(self.internalUserDecider.isInternalUser)")

        onUpdateCheckStart()
    }

    private func onUpdateCheckStart() {
        updateCheckResult = nil
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

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
<<<<<<< HEAD
        Logger.updates.debug("Updater did find valid update: \(item.displayVersionString)(\(item.versionString))")
=======
        os_log("Updater did find valid update: %{public}@",
               log: .updates,
               "\(item.displayVersionString)(\(item.versionString))")
>>>>>>> main

        PixelKit.fire(DebugEvent(GeneralPixel.updaterDidFindUpdate))

        if !automaticUpdateFlow {
            // For manual updates, we can present the available update without waiting for the update cycle to finish. The Sparkle flow downloads the update later
            updateCheckResult = UpdateCheckResult(item: item, isInstalled: false)
            onUpdateCheckEnd()
        }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        let item = (error as NSError).userInfo["SULatestAppcastItemFound"] as? SUAppcastItem
<<<<<<< HEAD
        Logger.updates.debug("Updater did not find update: \(String(describing: item?.displayVersionString))(\(String(describing: item?.versionString)))")

        onUpdateCheckEnd(item: item, isInstalled: true)
=======
        os_log("Updater did not find update: %{public}@",
               log: .updates,
               "\(item?.displayVersionString ?? "")(\(item?.versionString ?? ""))")
        if let item {
            // User is running the latest version
            updateCheckResult = UpdateCheckResult(item: item, isInstalled: true)
        }
>>>>>>> main

        PixelKit.fire(DebugEvent(GeneralPixel.updaterDidNotFindUpdate, error: error))
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
<<<<<<< HEAD
        Logger.updates.debug("Updater did download update: \(item.displayVersionString)(\(item.versionString))")
=======
        os_log("Updater did download update: %{public}@",
               log: .updates,
               "\(item.displayVersionString)(\(item.versionString))")
>>>>>>> main

        if automaticUpdateFlow {
            // For automatic updates, the available item has to be downloaded
            updateCheckResult = UpdateCheckResult(item: item, isInstalled: false)
            return
        }

        PixelKit.fire(DebugEvent(GeneralPixel.updaterDidDownloadUpdate))
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        os_log("Updater did finish update cycle", log: .updates)

        onUpdateCheckEnd()
    }

    private func onUpdateCheckEnd() {
        guard isUpdateBeingLoaded else {
            // The update check end is already handled
            return
        }

        // If the update is available, present it
        if let updateCheckResult = updateCheckResult {
            latestUpdate = Update(appcastItem: updateCheckResult.item,
                                  isInstalled: updateCheckResult.isInstalled)
        } else {
            latestUpdate = nil
        }

<<<<<<< HEAD
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        Logger.updates.debug("Updater did finish update cycle")
=======
        // Clear cache
        isUpdateBeingLoaded = false
        updateCheckResult = nil
>>>>>>> main
    }

}

#endif
