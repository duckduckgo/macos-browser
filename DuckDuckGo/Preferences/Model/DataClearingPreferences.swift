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

    static let burnOnQuitNotificationKey = "isBurnDataOnQuitEnabled"
    static let shared = DataClearingPreferences()

    @Published
    var isLoginDetectionEnabled: Bool {
        didSet {
            persistor.loginDetectionEnabled = isLoginDetectionEnabled
        }
    }

    @Published
    var isBurnDataOnQuitEnabled: Bool {
        didSet {
            persistor.burnDataOnQuitEnabled = isBurnDataOnQuitEnabled
            NotificationCenter.default.post(name: .burnDataOnQuitDidChange,
                                            object: nil,
                                            userInfo: [Self.burnOnQuitNotificationKey: isBurnDataOnQuitEnabled])
        }
    }

    @Published
    var isWarnBeforeClearingEnabled: Bool {
        didSet {
            persistor.warnBeforeClearingEnabled = isWarnBeforeClearingEnabled
        }
    }

    @Published
    var clearDataAfter: ClearDataAfterOption = .quittingAppOnly {
        didSet {
            persistor.clearDataAfter = clearDataAfter
        }
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
        isBurnDataOnQuitEnabled = persistor.burnDataOnQuitEnabled
        isWarnBeforeClearingEnabled = persistor.warnBeforeClearingEnabled
        clearDataAfter = persistor.clearDataAfter
    }

    private var persistor: FireButtonPreferencesPersistor
}

protocol FireButtonPreferencesPersistor {
    var loginDetectionEnabled: Bool { get set }
    var burnDataOnQuitEnabled: Bool { get set }
    var warnBeforeClearingEnabled: Bool { get set }
    var clearDataAfter: ClearDataAfterOption { get set }
}

struct FireButtonPreferencesUserDefaultsPersistor: FireButtonPreferencesPersistor {

    @UserDefaultsWrapper(key: .loginDetectionEnabled, defaultValue: false)
    var loginDetectionEnabled: Bool

    @UserDefaultsWrapper(key: .burnDataOnQuitEnabled, defaultValue: false)
    var burnDataOnQuitEnabled: Bool

    @UserDefaultsWrapper(key: .warnBeforeClearingEnabled, defaultValue: false)
    var warnBeforeClearingEnabled: Bool

    @UserDefaultsWrapper(key: .clearDataAfter, defaultValue: .quittingAppOnly)
    var clearDataAfter: ClearDataAfterOption

}

enum ClearDataAfterOption: String, CaseIterable {
    case quittingAppOnly
    case quittingApp30MinutesOfInactivity
    case quittingApp2HoursOfInactivity
    case quittingApp8HoursOfInactivity
    case quittingApp1DayOfInactivity

    var timeInterval: TimeInterval? {
        switch self {
        case .quittingAppOnly: return nil
        case .quittingApp30MinutesOfInactivity: return 30 * 60
        case .quittingApp2HoursOfInactivity: return 2 * 60 * 60
        case .quittingApp8HoursOfInactivity: return 8 * 60 * 60
        case .quittingApp1DayOfInactivity: return 24 * 60 * 60
        }
    }
}

extension Notification.Name {
    static let burnDataOnQuitDidChange = Notification.Name("burnDataOnQuitDidChange")
}
