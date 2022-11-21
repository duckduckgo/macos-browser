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
import BrowserServicesKit

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {

    static var isRunningTests: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #else
        return false
        #endif
    }

    #if DEBUG
    let disableCVDisplayLinkLogs: Void = {
        // Disable CVDisplayLink logs
        CFPreferencesSetValue("cv_note" as CFString,
                              0 as CFPropertyList,
                              "com.apple.corevideo" as CFString,
                              kCFPreferencesCurrentUser,
                              kCFPreferencesAnyHost)
        CFPreferencesSynchronize("com.apple.corevideo" as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }()
    #endif

    let urlEventHandler = URLEventHandler()

    private let keyStore = EncryptionKeyStore()
    private var fileStore: FileStore!
    private(set) var stateRestorationManager: AppStateRestorationManager!
    private var grammarFeaturesManager = GrammarFeaturesManager()
    private let crashReporter = CrashReporter()
    let updateController = UpdateController()

    var appUsageActivityMonitor: AppUsageActivityMonitor?

    func applicationWillFinishLaunching(_ notification: Notification) {
        if !Self.isRunningTests {
            #if DEBUG
            Pixel.setUp(dryRun: true)
            #else
            Pixel.setUp()
            #endif

            Database.shared.loadStore { _, error in
                guard let error = error else { return }
                
                switch error {
                case CoreDataDatabase.Error.containerLocationCouldNotBePrepared(let underlyingError):
                    Pixel.fire(.debug(event: .dbContainerInitializationError, error: underlyingError))
                default:
                    Pixel.fire(.debug(event: .dbInitializationError, error: error))
                }
                
                // Give Pixel a chance to be sent, but not too long
                Thread.sleep(forTimeInterval: 1)
                fatalError("Could not load DB: \(error.localizedDescription)")
            }
        }

        do {
            let encryptionKey = Self.isRunningTests ? nil : try keyStore.readKey()
            fileStore = EncryptedFileStore(encryptionKey: encryptionKey)
        } catch {
            os_log("App Encryption Key could not be read: %s", "\(error)")
            fileStore = EncryptedFileStore()
        }
        stateRestorationManager = AppStateRestorationManager(fileStore: fileStore)
        stateRestorationManager.subscribeToAutomaticAppRelaunching(using: updateController.willRelaunchAppPublisher)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningTests else { return }

        HistoryCoordinator.shared.loadHistory()
        PrivacyFeatures.httpsUpgrade.loadDataAsync()
        LocalBookmarkManager.shared.loadBookmarks()
        FaviconManager.shared.loadFavicons()
        ConfigurationManager.shared.start()
        _ = DownloadListCoordinator.shared
        _ = RecentlyClosedCoordinator.shared

        AtbAndVariantCleanup.cleanup()
        DefaultVariantManager().assignVariantIfNeeded { _ in
            // MARK: perform first time launch logic here
        }

        stateRestorationManager.applicationDidFinishLaunching()

        BWManager.shared.initCommunication()

        if WindowsManager.windows.isEmpty {
            WindowsManager.openNewWindow(lazyLoadTabs: true)
        }

        grammarFeaturesManager.manage()

        applyPreferredTheme()

        appUsageActivityMonitor = AppUsageActivityMonitor(delegate: self)

        crashReporter.checkForNewReports()

        urlEventHandler.applicationDidFinishLaunching()

        UserDefaultsWrapper<Any>.clearRemovedKeys()
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
        if WindowControllersManager.shared.mainWindowControllers.isEmpty {
            WindowsManager.openNewWindow()
            return true
        }
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        return ApplicationDockMenu()
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
        // This is temporarily unused while we determine whether it required to determine an active user count.
    }

}
