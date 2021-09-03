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

    let urlEventListener = UrlEventListener(handler: AppDelegate.handleURL)

    private let keyStore = EncryptionKeyStore()
    private var fileStore: FileStore!
    private var stateRestorationManager: AppStateRestorationManager!
    private var grammarFeaturesManager = GrammarFeaturesManager()

    private var urlsToOpen: [URL]?

    private var didFinishLaunching = false

#if OUT_OF_APPSTORE

    let updateController = UpdateController()

    let crashReporter = CrashReporter()

#endif

    var appUsageActivityMonitor: AppUsageActivityMonitor?

    // locked-to-URL app (App Tab/Web App mode)
    fileprivate var appTabURL: URL?
    fileprivate var isAppTab: Bool {
        appTabURL != nil
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
#if BETA
        if NSApp.buildDate < Date.monthAgo {
            let message = "DuckDuckGo Beta has expired.\nPlease, delete the App and empty the Recycle Bin."
            NSAlert(error: NSError(domain: "App Expired", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
                .runModal()
            NSApp.terminate(nil)
        }
#endif

        // Load AppTab fixed URL from Bundle Extended Attributes (if set)
        self.appTabURL = FileManager.default.extendedAttributeValue(forKey: AppTabMaker.appTabURLKey, at: Bundle.main.bundleURL)

        if appTabURL != nil {
            // If browser app is newer than this copy, update self
            checkForMainBrowserUpdates()
        }
        checkLaunchArgs()

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

        if !isAppTab {
#if !BETA
            updateController.configureUpdater()
#endif
            stateRestorationManager = AppStateRestorationManager(fileStore: fileStore)
        }

        urlEventListener.listen()
    }

    private func checkLaunchArgs() {
        let processInfo = ProcessInfo()
        // Web App requests updating itself from current Bundle
        if processInfo.arguments[safe: 1] == "--update-me",
           let url = processInfo.arguments[safe: 2].map(URL.init(fileURLWithPath:)),
           Bundle(url: url)?.bundleIdentifier == Bundle.main.bundleIdentifier,
           let appTabURL: URL = FileManager.default.extendedAttributeValue(forKey: AppTabMaker.appTabURLKey,
                                                                            at: url) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)

            AppTabMaker().makeAppTab(at: url, for: appTabURL, icon: icon) { error in
                if let error = error {
                    NSAlert(error: error).runModal()
                }
                exit(0)
            }
            RunLoop.current.run(until: .distantFuture)

        // Web App requests checking for updates
        } else if processInfo.arguments[safe: 1] == "--check-for-updates" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.checkForUpdates(nil)
            }
        }
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

        if let url = appTabURL {
            self.urlsToOpen = nil
            self.appTabURL = url

            WindowsManager.openNewWindow(with: url)
        } else {
            stateRestorationManager.applicationDidFinishLaunching()

            if WindowsManager.windows.isEmpty {
                WindowsManager.openNewWindow()
            }
        }

        grammarFeaturesManager.manage()

        applyPreferredTheme()

        launchTimingPixel.fire()

        appUsageActivityMonitor = AppUsageActivityMonitor(delegate: self)

#if OUT_OF_APPSTORE

        crashReporter.checkForNewReports()

#endif

        if isAppTab {
            // Disable Bookmarks menu
            NSApp.mainMenuTyped.bookmarksMenuItem?.isHidden = true
            // Change Process Name to Bundle Name
            try? ProcessInfo().setProcessName(Bundle.main.bundleURL.deletingPathExtension().lastPathComponent)

        } else {
            subscribeToDistributedNotifications()
        }

        if let urlsToOpen = urlsToOpen {
            for url in urlsToOpen {
                Self.handleURL(url)
            }
        }

        didFinishLaunching = true
    }

    private var urlNotificationObserver: Any?
    private var updateNotificationObserver: Any?

    func subscribeToDistributedNotifications() {
        let notificationCenter = DistributedNotificationCenter.default()
        urlNotificationObserver = notificationCenter.addObserver(self,
                                                                 selector: #selector(openURLNotification(_:)),
                                                                 name: .openURL,
                                                                 object: nil)
        updateNotificationObserver = notificationCenter.addObserver(self,
                                                                    selector: #selector(checkForUpdatesNotification(_:)),
                                                                    name: .checkForUpdates,
                                                                    object: nil)
    }

    @objc
    func openURLNotification(_ notification: Notification) {
        guard let string = notification.object as? String,
              let obj = try? OpenURLNotificationMessage.fromString(string),
              obj.pid == NSRunningApplication.current.processIdentifier
        else { return }

        Self.handleURL(obj.url)
    }

    @objc
    func checkForUpdatesNotification(_ notification: Notification) {
        guard let msg = notification.object as? String,
              let pid = pid_t(msg),
              pid == NSRunningApplication.current.processIdentifier
        else { return }

        NSApp.activate(ignoringOtherApps: true)
        self.checkForUpdates(nil)
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

    // Web App checks if the Main Browser is newer than the Web App
    private func checkForMainBrowserUpdates() {
        guard let browserURL = NSWorkspace.shared.browserAppURL(),
              (Bundle.main.bundleURL.appendingPathComponent("Contents/Info.plist").modificationDate ?? .distantPast)
                < (browserURL.appendingPathComponent("Contents/Info.plist").modificationDate ?? .distantPast)
        else { return }

        // run update cycle
        NSWorkspace.shared.openApplication(at: browserURL, with: ["--update-me", Bundle.main.bundleURL.path], newInstance: true) { _, _ in
            exit(0)
        }
        RunLoop.current.run(until: .distantPast)
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

extension NSApplication {

    var isAppTab: Bool {
        (delegate as? AppDelegate)!.isAppTab
    }

    var appTabURL: URL? {
        (delegate as? AppDelegate)!.appTabURL
    }
}
