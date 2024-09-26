//
//  AutofillLoginImportState.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import BrowserServicesKit

protocol AutofillLoginImportStateStoring {
    var isCredentialsImportPromptPermanantlyDismissed: Bool { get set }
}

final class AutofillLoginImportState: AutofillLoginImportStateProvider, AutofillLoginImportStateStoring {
    private enum Key {
        static let hasImportedLogins: String = "com.duckduckgo.logins.hasImportedLogins"
        static let credentialsImportPromptPresentationCount: String = "com.duckduckgo.logins.credentialsImportPromptPresentationCount"
        static let isCredentialsImportPromptPermanantlyDismissed: String = "com.duckduckgo.logins.isCredentialsImportPromptPermanantlyDismissed"
    }

    private let userDefaults: UserDefaults

    public var isEligibleDDGUser: Bool {
        guard let date = userDefaults.object(forKey: UserDefaultsWrapper<Date>.Key.firstLaunchDate.rawValue) as? Date else {
            return true
        }
        return date >= Date.weekAgo
    }

    public var hasImportedLogins: Bool {
        get {
            userDefaults.bool(forKey: Key.hasImportedLogins)
        }

        set {
            userDefaults.set(newValue, forKey: Key.hasImportedLogins)
        }
    }

    public var credentialsImportPromptPresentationCount: Int {
        get {
            userDefaults.integer(forKey: Key.credentialsImportPromptPresentationCount)
        }

        set {
            userDefaults.set(newValue, forKey: Key.credentialsImportPromptPresentationCount)
        }
    }

    public var isAutofillEnabled: Bool {
        AutofillPreferences().askToSaveUsernamesAndPasswords
    }

    public var isCredentialsImportPromptPermanantlyDismissed: Bool {
        get {
            userDefaults.bool(forKey: Key.isCredentialsImportPromptPermanantlyDismissed)
        }

        set {
            userDefaults.set(newValue, forKey: Key.isCredentialsImportPromptPermanantlyDismissed)
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func hasNeverPromptWebsitesFor(_ domain: String) -> Bool {
        AutofillNeverPromptWebsitesManager.shared.hasNeverPromptWebsitesFor(domain: domain)
    }
}
