//
//  AppDelegate.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import Cocoa
import Combine
import os.log

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {

    let launchTimingPixel = TimedPixel(.launchTiming)

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    let urlEventHandler = URLEventHandler()

    private let keyStore = EncryptionKeyStore()
    private var fileStore: FileStore!
    private var stateRestorationManager: AppStateRestorationManager!
    private var grammarFeaturesManager = GrammarFeaturesManager()

#if OUT_OF_APPSTORE

#if !BETA
    let updateController = UpdateController()
#endif

    let crashReporter = CrashReporter()

#endif

    var appUsageActivityMonitor: AppUsageActivityMonitor?

    func applicationWillFinishLaunching(_ notification: Notification) {
        ExpirationChecker.check()

        if !Self.isRunningTests {
#if DEBUG
            Pixel.setUp(dryRun: true)
#else
            Pixel.setUp()
#endif

            Database.shared.loadStore()
        }

        do {
            let encryptionKey = Self.isRunningTests ? nil : try keyStore.readKey()
            fileStore = EncryptedFileStore(encryptionKey: encryptionKey)
        } catch {
            os_log("App Encryption Key could not be read: %s", "\(error)")
            fileStore = EncryptedFileStore()
        }
        stateRestorationManager = AppStateRestorationManager(fileStore: fileStore)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningTests else { return }

        HTTPSUpgrade.shared.loadDataAsync()
        LocalBookmarkManager.shared.loadBookmarks()
        _=ConfigurationManager.shared
        _=DownloadListCoordinator.shared

        AtbAndVariantCleanup.cleanup()
        DefaultVariantManager().assignVariantIfNeeded { _ in
            // MARK: perform first time launch logic here
        }

        if (notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? NSNumber)?.boolValue == true {
            Pixel.fire(.appLaunch(launch: .autoInitialOrRegular()))
        }

        stateRestorationManager.applicationDidFinishLaunching()

        if WindowsManager.windows.isEmpty {
            WindowsManager.openNewWindow()
        }

        grammarFeaturesManager.manage()

        applyPreferredTheme()

        launchTimingPixel.fire()

        appUsageActivityMonitor = AppUsageActivityMonitor(delegate: self)

#if OUT_OF_APPSTORE
        crashReporter.checkForNewReports()
#endif
        urlEventHandler.applicationDidFinishLaunching()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if !FileDownloadManager.shared.downloads.isEmpty {
            let alert = NSAlert.activeDownloadsTerminationAlert(for: FileDownloadManager.shared.downloads)
            if alert.runModal() == .cancel {
                return .terminateCancel
            }
            FileDownloadManager.shared.cancelAll(waitUntilDone: true)
            DownloadListCoordinator.shared.sync()
        }
        stateRestorationManager?.applicationWillTerminate()

        return .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            WindowsManager.openNewWindow()
            return true
        }
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let applicationDockMenu = ApplicationDockMenu()
        applicationDockMenu.dataSource = WindowControllersManager.shared
        applicationDockMenu.applicationDockMenuDelegate = WindowControllersManager.shared
        return applicationDockMenu
    }

    func application(_ sender: NSApplication, openFiles files: [String]) {
        urlEventHandler.handleFiles(files)
    }

    private func applyPreferredTheme() {
        let appearancePreferences = AppearancePreferences()
        appearancePreferences.updateUserInterfaceStyle()
    }

}

extension AppDelegate: AppUsageActivityMonitorDelegate {

    func countOpenWindowsAndTabs() -> [Int] {
        return WindowControllersManager.shared.mainWindowControllers
            .map { $0.mainViewController.tabCollectionViewModel.tabCollection.tabs.count }
    }

    func activeUsageTimeHasReachedThreshold(avgTabCount: Double) {
        Pixel.fire(.appActiveUsage(avgTabs: .init(avgTabs: avgTabCount)))
    }

}
