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

    let downloadsCoordinator = DownloadListCoordinator.shared
    let launchTimingPixel = TimedPixel(.launchTiming)

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    let urlEventListener = UrlEventListener(handler: AppDelegate.handleURL)

    private let keyStore = EncryptionKeyStore()
    private var fileStore: FileStore!
    private var stateRestorationManager: AppStateRestorationManager!
    private var grammarFeaturesManager = GrammarFeaturesManager()

    private var urlsToOpen: [URL]?

    private var didFinishLaunching = false

#if OUT_OF_APPSTORE

#if !BETA
    let updateController = UpdateController()
#endif

    let crashReporter = CrashReporter()

#endif

    var appUsageActivityMonitor: AppUsageActivityMonitor?

    func applicationWillFinishLaunching(_ notification: Notification) {
#if BETA
        if NSApp.buildDate < Date.monthAgo {
            let message = "DuckDuckGo Beta has expired.\nPlease, delete the App and empty the Recycle Bin."
            NSAlert(error: NSError(domain: "App Expired", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
                .runModal()
            NSApp.terminate(nil)
        }
#endif

        if !Self.isRunningTests {
            Pixel.setUp()
        }

        do {
            let encryptionKey = Self.isRunningTests ? nil : try keyStore.readKey()
            fileStore = EncryptedFileStore(encryptionKey: encryptionKey)
        } catch {
            os_log("App Encryption Key could not be read: %s", "\(error)")
            fileStore = EncryptedFileStore()
        }
        stateRestorationManager = AppStateRestorationManager(fileStore: fileStore)

        urlEventListener.listen()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningTests else { return }
        
        Database.shared.loadStore()
        HTTPSUpgrade.shared.loadDataAsync()
        LocalBookmarkManager.shared.loadBookmarks()
        _=ConfigurationManager.shared

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

        if let urlsToOpen = urlsToOpen {
            for url in urlsToOpen {
                Self.handleURL(url)
            }
        }

        didFinishLaunching = true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
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
        let urlsToOpen: [URL] = files.compactMap {
            if let url = URL(string: $0),
               ["http", "https"].contains(url.scheme) {
                return url
            } else if FileManager.default.fileExists(atPath: $0) {
                let url = URL(fileURLWithPath: $0)
                return url
            }
            return nil
        }
        if didFinishLaunching {
            urlsToOpen.forEach(Self.handleURL)
        } else {
            self.urlsToOpen = urlsToOpen
        }
    }

    static func handleURL(_ url: URL) {
        Pixel.fire(.appLaunch(launch: url.isFileURL ? .openFile : .openURL))

        WindowControllersManager.shared.show(url: url, newTab: true)
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
