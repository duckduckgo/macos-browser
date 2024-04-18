//
//  DataClearingPreferences.swift
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

final class DataClearingPreferences: ObservableObject, PreferencesTabOpening {

    static let shared = DataClearingPreferences()

    @Published
    var isLoginDetectionEnabled: Bool {
        didSet {
            persistor.loginDetectionEnabled = isLoginDetectionEnabled
        }
    }

    @Published
    var isAutoClearEnabled: Bool {
        didSet {
            persistor.autoClearEnabled = isAutoClearEnabled
            NotificationCenter.default.post(name: .autoClearDidChange,
                                            object: nil,
                                            userInfo: nil)
        }
    }

    @Published
    var isWarnBeforeClearingEnabled: Bool {
        didSet {
            persistor.warnBeforeClearingEnabled = isWarnBeforeClearingEnabled
        }
    }

    @objc func toggleWarnBeforeClearing() {
        isWarnBeforeClearingEnabled.toggle()
    }

    @MainActor
    func presentManageFireproofSitesDialog() {
        let fireproofDomainsWindowController = FireproofDomainsViewController.create().wrappedInWindowController()

        guard let fireproofDomainsWindow = fireproofDomainsWindowController.window,
              let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController
        else {
            assertionFailure("DataClearingPreferences: Failed to present FireproofDomainsViewController")
            return
        }

        parentWindowController.window?.beginSheet(fireproofDomainsWindow)
    }

    init(persistor: FireButtonPreferencesPersistor = FireButtonPreferencesUserDefaultsPersistor()) {
        self.persistor = persistor
        isLoginDetectionEnabled = persistor.loginDetectionEnabled
        isAutoClearEnabled = persistor.autoClearEnabled
        isWarnBeforeClearingEnabled = persistor.warnBeforeClearingEnabled
    }

    private var persistor: FireButtonPreferencesPersistor
}

protocol FireButtonPreferencesPersistor {
    var loginDetectionEnabled: Bool { get set }
    var autoClearEnabled: Bool { get set }
    var warnBeforeClearingEnabled: Bool { get set }
}

struct FireButtonPreferencesUserDefaultsPersistor: FireButtonPreferencesPersistor {

    @UserDefaultsWrapper(key: .loginDetectionEnabled, defaultValue: false)
    var loginDetectionEnabled: Bool

    @UserDefaultsWrapper(key: .autoClearEnabled, defaultValue: false)
    var autoClearEnabled: Bool

    @UserDefaultsWrapper(key: .warnBeforeClearingEnabled, defaultValue: false)
    var warnBeforeClearingEnabled: Bool

}

extension Notification.Name {
    static let autoClearDidChange = Notification.Name("autoClearDidChange")
}
