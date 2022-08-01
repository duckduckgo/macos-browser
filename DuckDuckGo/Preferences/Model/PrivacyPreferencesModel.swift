//
//  PrivacyPreferencesModel.swift
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

final class PrivacyPreferencesModel: ObservableObject {

    @Published
    var isLoginDetectionEnabled: Bool {
        didSet {
            privacySecurityPreferences.loginDetectionEnabled = isLoginDetectionEnabled
        }
    }

    @Published
    var isGPCEnabled: Bool {
        didSet {
            privacySecurityPreferences.gpcEnabled = isGPCEnabled
        }
    }

    @Published var isAutoconsentEnabled: Bool {
        didSet {
            privacySecurityPreferences.autoconsentEnabled = isAutoconsentEnabled
        }
    }

    @Published
    var isPrivateYoutubePlayerEnabled: Bool {
        didSet {
            privacySecurityPreferences.privateYoutubePlayerEnabled = isPrivateYoutubePlayerEnabled
        }
    }

    func presentManageFireproofSitesDialog() {
        let fireproofDomainsWindowController = FireproofDomainsViewController.create().wrappedInWindowController()

        guard let fireproofDomainsWindow = fireproofDomainsWindowController.window,
              let parentWindowController = WindowControllersManager.shared.lastKeyMainWindowController
        else {
            assertionFailure("Privacy Preferences: Failed to present FireproofDomainsViewController")
            return
        }

        parentWindowController.window?.beginSheet(fireproofDomainsWindow)
    }

    func openURL(_ url: URL) {
        WindowControllersManager.shared.show(url: url, newTab: true)
    }

    init(privacySecurityPreferences: PrivacySecurityPreferences = .shared) {
        self.privacySecurityPreferences = privacySecurityPreferences
        isLoginDetectionEnabled = privacySecurityPreferences.loginDetectionEnabled
        isGPCEnabled = privacySecurityPreferences.gpcEnabled
        isAutoconsentEnabled = privacySecurityPreferences.autoconsentEnabled ?? false
        isPrivateYoutubePlayerEnabled = privacySecurityPreferences.privateYoutubePlayerEnabled ?? false
    }

    private let privacySecurityPreferences: PrivacySecurityPreferences
}
