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

    static let copySelector = #selector(AppDelegate.copy(_:))

    let launchTimingPixel = TimedPixel(.launchTiming)

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    let urlEventListener = UrlEventListener(handler: AppDelegate.handleURL)

    private let keyStore = EncryptionKeyStore()
    private var fileStore: FileStore!
    private var stateRestorationManager: AppStateRestorationManager!
    private var grammarCheckEnabler: GrammarCheckEnabler!

#if OUT_OF_APPSTORE

    let updateController = UpdateController()
    let crashReporter = CrashReporter()

#endif

    var appUsageActivityMonitor: AppUsageActivityMonitor?

    func applicationWillFinishLaunching(_ notification: Notification) {
        if !Self.isRunningTests {
            Pixel.setUp()
        }

        do {
            let encryptionKey = Self.isRunningTests ? nil : try keyStore.readKey()
            fileStore = FileStore(encryptionKey: encryptionKey)
        } catch {
            os_log("App Encryption Key could not be read: %s", "\(error)")
            fileStore = FileStore()
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

        grammarCheckEnabler = GrammarCheckEnabler(windowControllersManager: WindowControllersManager.shared)
        grammarCheckEnabler.enableIfNeeded()

        applyPreferredTheme()

        launchTimingPixel.fire()

        appUsageActivityMonitor = AppUsageActivityMonitor(delegate: self)

#if OUT_OF_APPSTORE

        crashReporter.checkForNewReports()

#endif

    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        stateRestorationManager.applicationWillTerminate()

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
        for path in files {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)

            Self.handleURL(url)
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

    @IBAction func copy(_ sender: Any?) {
        print(#function, sender as Any)

        guard let responder = NSApp.keyWindow?.firstResponder else { return }

        if responder is AddressBarTextEditor,
           let controller = NSApp.keyWindow?.contentViewController as? MainViewController,
           let url = controller.tabCollectionViewModel.selectedTabViewModel?.tab.url {

            // When copying from the address bar text field always use the URL in case we're showing something else

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.absoluteString, forType: .string)
            NSPasteboard.general.setString(url.absoluteString, forType: .URL)

        } else if responder.responds(to: Self.copySelector) {
            responder.perform(Self.copySelector)
        }

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
