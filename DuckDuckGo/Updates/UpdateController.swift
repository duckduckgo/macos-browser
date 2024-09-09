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

    var canCheckForUpdates: Bool { get }

    var hasPendingUpdate: Bool { get }
    var hasPendingUpdatePublisher: Published<Bool>.Publisher { get }

    var updateProgress: UpdateCycleProgress { get }
    var updateProgressPublisher: Published<UpdateCycleProgress>.Publisher { get }

    var lastUpdateCheckDate: Date? { get }

    func checkForUpdateIfNeeded()

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

    // Struct used to cache data until the updater finishes checking for updates
    struct UpdateCheckResult {
        let item: SUAppcastItem
        let isInstalled: Bool
    }
    private var updateCheckResult: UpdateCheckResult?

    init(internalUserDecider: InternalUserDecider) {
        willRelaunchAppPublisher = willRelaunchAppSubject.eraseToAnyPublisher()
        self.internalUserDecider = internalUserDecider
        super.init()

        try? configureUpdater()
    }

    @Published private(set) var updateProgress = UpdateCycleProgress.default {
        didSet {
            if let updateCheckResult {
                latestUpdate = Update(appcastItem: updateCheckResult.item, isInstalled: updateCheckResult.isInstalled)
                hasPendingUpdate = latestUpdate?.isInstalled == false && updateProgress.isIdle
            }
            showUpdateNotificationIfNeeded()
        }
    }

    var updateProgressPublisher: Published<UpdateCycleProgress>.Publisher { $updateProgress }

    @Published private(set) var latestUpdate: Update?

    var latestUpdatePublisher: Published<Update?>.Publisher { $latestUpdate }

    @Published private(set) var hasPendingUpdate = false
    var hasPendingUpdatePublisher: Published<Bool>.Publisher { $hasPendingUpdate }

    var lastUpdateCheckDate: Date? {
        updater?.lastUpdateCheckDate
    }

    var canCheckForUpdates: Bool {
        updater?.canCheckForUpdates == true
    }

    @UserDefaultsWrapper(key: .automaticUpdates, defaultValue: true)
    var areAutomaticUpdatesEnabled: Bool {
        didSet {
            Logger.updates.debug("areAutomaticUpdatesEnabled: \(self.areAutomaticUpdatesEnabled)")
            if oldValue != areAutomaticUpdatesEnabled {
                try? configureUpdater()
            }
        }
    }

    private(set) var updater: SPUUpdater?
    private(set) var userDriver: UpdateUserDriver?
    private let willRelaunchAppSubject = PassthroughSubject<Void, Never>()
    private var internalUserDecider: InternalUserDecider
    private var updateProcessCancellable: AnyCancellable!

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

    func checkForUpdateIfNeeded() {
        guard let updater, !updater.sessionInProgress else { return }

        Logger.updates.debug("Checking for updates")

        updater.checkForUpdates()
    }

    // MARK: - Private

    private func configureUpdater() throws {
        // Workaround to restart the updater state
        updateCheckResult = nil
        latestUpdate = nil

        // The default configuration of Sparkle updates is in Info.plist
        userDriver = UpdateUserDriver(internalUserDecider: internalUserDecider,
                                      areAutomaticUpdatesEnabled: areAutomaticUpdatesEnabled)
        guard let userDriver else { return }

        updater = SPUUpdater(hostBundle: Bundle.main, applicationBundle: Bundle.main, userDriver: userDriver, delegate: self)

        updateProcessCancellable = userDriver.updateProgressPublisher
            .assign(to: \.updateProgress, onWeaklyHeld: self)

        try updater?.start()

#if DEBUG
//        updater.automaticallyChecksForUpdates = false
//        updater.automaticallyDownloadsUpdates = false
//        updater.updateCheckInterval = 0
#endif

        checkForUpdateIfNeeded()
    }

    private func showUpdateNotificationIfNeeded() {
        guard let latestUpdate, hasPendingUpdate else { return }

        switch latestUpdate.type {
        case .critical:
            notificationPresenter.showUpdateNotification(icon: NSImage.criticalUpdateNotificationInfo, text: UserText.criticalUpdateNotification, presentMultiline: true)
        case .regular:
            notificationPresenter.showUpdateNotification(icon: NSImage.updateNotificationInfo, text: UserText.updateAvailableNotification, presentMultiline: true)
        }
    }

    @objc func openUpdatesPage() {
        notificationPresenter.openUpdatesPage()
    }

    @objc func runUpdate() {
        if let userDriver {
            PixelKit.fire(DebugEvent(GeneralPixel.updaterDidRunUpdate))
            userDriver.resume()
        }
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

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Logger.updates.debug("Updater did find valid update: \(item.displayVersionString)(\(item.versionString))")
        PixelKit.fire(DebugEvent(GeneralPixel.updaterDidFindUpdate))
        updateCheckResult = UpdateCheckResult(item: item, isInstalled: false)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        let nsError = error as NSError
        guard let item = nsError.userInfo["SULatestAppcastItemFound"] as? SUAppcastItem else { return }

        Logger.updates.debug("Updater did not find update: \(String(describing: item.displayVersionString))(\(String(describing: item.versionString)))")
        PixelKit.fire(DebugEvent(GeneralPixel.updaterDidNotFindUpdate, error: error))

        updateCheckResult = UpdateCheckResult(item: item, isInstalled: true)
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        Logger.updates.debug("Updater did download update: \(item.displayVersionString)(\(item.versionString))")
        PixelKit.fire(DebugEvent(GeneralPixel.updaterDidDownloadUpdate))
    }

    func updater(_ updater: SPUUpdater, didExtractUpdate item: SUAppcastItem) {
        Logger.updates.debug("Updater did extract update: \(item.displayVersionString)(\(item.versionString))")
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        Logger.updates.debug("Updater will install update: \(item.displayVersionString)(\(item.versionString))")
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        Logger.updates.debug("Updater did finish update cycle")
        updateProgress = .updateCycleDone
    }

}

#endif
