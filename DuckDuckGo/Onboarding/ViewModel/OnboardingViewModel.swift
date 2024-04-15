//
//  OnboardingViewModel.swift
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

import SwiftUI

protocol OnboardingDelegate: NSObjectProtocol {

    /// Import data UI should be launched.  Whatever happens, call the completion to move on to the next screen.
    func onboardingDidRequestImportData(completion: @escaping () -> Void)

    /// Request set default should be launched.  Whatever happens, call the completion to move on to the next screen.
    func onboardingDidRequestSetDefault(completion: @escaping () -> Void)

    /// Has finished, but still showing a screen.  This is when to re-enable the UI.
    func onboardingHasFinished()

}

final class OnboardingViewModel: ObservableObject {

    enum OnboardingPhase {

        case startFlow
        case welcome
        case importData
        case setDefault
        case startBrowsing

    }

    var typingDisabled = false

    @Published var skipTypingRequested = false
    @Published var state: OnboardingPhase = .startFlow {
        didSet {
            skipTypingRequested = false
        }
    }

    @UserDefaultsWrapper(key: .onboardingFinished, defaultValue: false)
    private static var _isOnboardingFinished: Bool

    @MainActor
    private(set) static var isOnboardingFinished: Bool {
        get {
            guard !_isOnboardingFinished else { return true }

            // when there‘s a restored state but Onboarding Finished flag is not set - set it
            guard WindowsManager.mainWindows.count <= 1 else {
                OnboardingViewModel.isOnboardingFinished = true
                return true
            }
            guard let tabsContent = (WindowsManager.mainWindows.first?.contentViewController as? MainViewController)?.tabCollectionViewModel.tabs.map(\.content) else { return false }
            if !tabsContent.isEmpty, tabsContent != [.newtab] {
                // there‘s some tabs content not equal to the new tab page: it means there‘s a session restored
                OnboardingViewModel.isOnboardingFinished = true
                return true
            }
            return false
        }
        set {
            _isOnboardingFinished = newValue


        }
    }

    weak var delegate: OnboardingDelegate?

    init(delegate: OnboardingDelegate? = nil) {
        self.delegate = delegate
    }

    func onSplashFinished() {
        state = .welcome
    }

    func onStartPressed() {
        state = .importData
    }

    func onImportPressed() {
        delegate?.onboardingDidRequestImportData { [weak self] in
            self?.state = .setDefault
        }
    }

    func onImportSkipped() {
        state = .setDefault
    }

    @MainActor
    func onSetDefaultPressed() {
        delegate?.onboardingDidRequestSetDefault { [weak self] in
            self?.state = .startBrowsing
            Self.isOnboardingFinished = true
            self?.addCurrentApplicationToDock()
            self?.delegate?.onboardingHasFinished()
        }
    }

    func addCurrentApplicationToDock() {
        let appPath = Bundle.main.bundleURL.path
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        let dockPlistPath = NSString(string: "~/Library/Preferences/com.apple.dock.plist").expandingTildeInPath
        let dockPlistURL = URL(fileURLWithPath: dockPlistPath)

        guard var dockPlistDict = NSDictionary(contentsOf: dockPlistURL) as? [String: AnyObject] else {
            return
        }

        var persistentApps = dockPlistDict["persistent-apps"] as? [[String: AnyObject]] ?? []
        var recentApps = dockPlistDict["recent-apps"] as? [[String: AnyObject]] ?? []

        // Check if the application is already in the persistent apps
        let isAppAlreadyInPersistentApps = persistentApps.contains { appDict in
            if let tileData = appDict["tile-data"] as? [String: AnyObject],
               let appBundleIdentifier = tileData["bundle-identifier"] as? String {
                return appBundleIdentifier == bundleIdentifier
            }
            return false
        }

        if isAppAlreadyInPersistentApps {
            return
        }

        // Find the app in recent apps
        if let recentAppIndex = recentApps.firstIndex(where: { appDict in
            if let tileData = appDict["tile-data"] as? [String: AnyObject],
               let appBundleIdentifier = tileData["bundle-identifier"] as? String {
                return appBundleIdentifier == bundleIdentifier
            }
            return false
        }) {
            let appDict = recentApps[recentAppIndex]
            // Move from recent to persistent
            persistentApps.append(appDict)
        } else {
            // Create the dictionary for the current application if not found in recent apps
            let appDict: [String: AnyObject] = ["tile-data": ["file-data": ["_CFURLString": "file://" + appPath + "/", "_CFURLStringType": 0]] as AnyObject]
            persistentApps.append(appDict)
        }

        // Update the plist
        dockPlistDict["persistent-apps"] = persistentApps as AnyObject?
        dockPlistDict["recent-apps"] = recentApps as AnyObject?

        // Mofidy the mod-count
        if let modCount = dockPlistDict["mod-count"] as? Int {
            dockPlistDict["mod-count"] = (modCount + 1) as AnyObject?
        } else {
            assertionFailure("mod-count modification failed")
        }

        // Write
        do {
            try (dockPlistDict as NSDictionary).write(to: dockPlistURL)
        } catch {
            return
        }

        // Restart the Dock to apply changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.restartDock()
        }
    }

    func restartDock() {
        let task = Process()
        task.launchPath = "/usr/bin/killall"
        task.arguments = ["Dock"]
        task.launch()
    }

    @MainActor
    func onSetDefaultSkipped() {
        state = .startBrowsing
        Self.isOnboardingFinished = true
        addCurrentApplicationToDock()
        delegate?.onboardingHasFinished()
    }

    func skipTyping() {
        skipTypingRequested = true
    }

    @MainActor
    func onboardingReshown() {
        if Self.isOnboardingFinished {
            typingDisabled = true
            delegate?.onboardingHasFinished()
        } else {
            state = .startFlow
        }
    }

}
