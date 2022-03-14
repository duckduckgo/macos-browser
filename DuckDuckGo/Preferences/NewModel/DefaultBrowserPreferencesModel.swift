//
//  DefaultBrowserPreferencesModel.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import SwiftUI
import Combine

final class DefaultBrowserPreferencesModel: ObservableObject {
    
    @Published var isDefault: Bool = false
    
    private var appDidBecomeActiveCancellable: AnyCancellable?
    
    init() {
        appDidBecomeActiveCancellable = NSApp.isActivePublisher()
            .filter { $0 }
            .sink { [unowned self] _ in
                checkIfDefault()
            }
        
        checkIfDefault()
    }
    
    func checkIfDefault() {
        var bundleID = AppVersion.shared.identifier
        #if DEBUG
        bundleID = bundleID.drop(suffix: ".debug")
        #endif

        guard let defaultBrowserURL = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "http://")!),
              // Another App Instance of the Browser may be already registered as the scheme handler
              let ddgBrowserURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else {
            isDefault = false
            return
        }

        isDefault = ddgBrowserURL == defaultBrowserURL
    }

    func becomeDefault() {
        if !presentDefaultBrowserPromptIfPossible() {
            openSystemPreferences()
        }
    }

    private func presentDefaultBrowserPromptIfPossible() -> Bool {
        let bundleID = AppVersion.shared.identifier

        let result = LSSetDefaultHandlerForURLScheme("http" as CFString, bundleID as CFString)
        return result == 0
    }

    private func openSystemPreferences() {
        // Apple provides a more general URL for opening System Preferences in the form of "x-apple.systempreferences:com.apple.preference" but it
        // doesn't support opening the Appearance prefpane directly.
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Appearance.prefPane"))
    }
}
