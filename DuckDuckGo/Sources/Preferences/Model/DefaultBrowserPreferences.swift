//
//  DefaultBrowserPreferences.swift
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

struct DefaultBrowserPreferences {

    static var isDefault: Bool {
        var bundleID = AppVersion.shared.identifier
        #if DEBUG
        bundleID = bundleID.drop(suffix: ".debug")
        #endif

        guard let defaultBrowserURL = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "http://")!),
              // Another App Instance of the Browser may be already registered as the scheme handler
              let ddgBrowserURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else {
            return false
        }

        return ddgBrowserURL == defaultBrowserURL
    }

    static func becomeDefault(_ completion: (() -> Void)? = nil) {
        if completion != nil {
            var observer: Any?
            observer = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                NotificationCenter.default.removeObserver(observer as Any)
                completion?()
            }
        }

        if !presentDefaultBrowserPromptIfPossible() {
            openSystemPreferences()
        }
    }

    private static func presentDefaultBrowserPromptIfPossible() -> Bool {
        let bundleID = AppVersion.shared.identifier

        let result = LSSetDefaultHandlerForURLScheme("http" as CFString, bundleID as CFString)
        return result == 0
    }

    private static func openSystemPreferences() {
        // Apple provides a more general URL for opening System Preferences in the form of "x-apple.systempreferences:com.apple.preference" but it
        // doesn't support opening the Appearance prefpane directly.
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Appearance.prefPane"))
    }

}

extension DefaultBrowserPreferences: PreferenceSection {

    var displayName: String {
        return UserText.defaultBrowser
    }

    var preferenceIcon: NSImage {
        return NSImage(named: "DefaultBrowser")!
    }

}
