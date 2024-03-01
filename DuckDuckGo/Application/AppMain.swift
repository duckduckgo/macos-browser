//
//  AppMain.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import AppKit

@main
struct AppMain {

#if CI || DEBUG || REVIEW
    static func applyUITestsEnvironment() {
        let uiTestsEnvironment = ProcessInfo().uiTestsEnvironment
#if !APPSTORE
        if let value = uiTestsEnvironment[.suppressMoveToApplications]?.boolValue {
            UserDefaultsWrapper<Bool?>.sharedDefaults.set(value, forKey: AlertSuppressKey)
        }
#endif
        if let value = uiTestsEnvironment[.onboardingFinished]?.boolValue {
            if value {
                UserDefaultsWrapper<Bool?>(key: .onboardingFinished).wrappedValue = true
            } else {
                UserDefaultsWrapper<Bool?>(key: .onboardingFinished).clear()
            }
        }
        if let value = uiTestsEnvironment[.shouldRestorePreviousSession]?.boolValue {
            UserDefaultsWrapper<Bool?>(key: .restorePreviousSession).wrappedValue = value
        }
        if uiTestsEnvironment[.resetSavedState] == .true {
            try? FileManager.default.removeItem(at: URL.sandboxApplicationSupportURL.appending(AppStateRestorationManager.fileName))
        }
    }
#else
    static func applyUITestsEnvironment() {}
#endif

    static func main() {
        _=Application.shared
        applyUITestsEnvironment()

#if !APPSTORE && !DEBUG
        // this should be run after NSApplication.shared is set
        PFMoveToApplicationsFolderIfNecessary(true)
#endif

        Application.shared.run()
    }

}
