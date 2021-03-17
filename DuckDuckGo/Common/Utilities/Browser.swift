//
//  Browser.swift
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

struct Browser {

    static var isDefault: Bool {
        guard let defaultBrowserURL = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "http://")!) else {
            return false
        }

        return Bundle.main.bundleURL == defaultBrowserURL
    }

    static func becomeDefault() {
        if !presentDefaultBrowserPromptIfPossible() {
            openSystemPreferences()
        }
    }

    private static func presentDefaultBrowserPromptIfPossible() -> Bool {
        guard let bundleID = Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String else {
            return false
        }

         let httpResult = LSSetDefaultHandlerForURLScheme("http" as CFString, bundleID as CFString)
         return httpResult == 0
    }

    private static func openSystemPreferences() {
        // Apple provides a more general URL for opening System Preferences in the form of "x-apple.systempreferences:com.apple.preference" but it
        // doesn't support opening the General prefpane directly.
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Appearance.prefPane"))
    }

}
