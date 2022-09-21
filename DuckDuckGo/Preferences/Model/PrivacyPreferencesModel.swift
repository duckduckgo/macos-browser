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
import Combine

final class PrivacyPreferencesModel: ObservableObject {

    enum PrivatePlayerMode {
        case enabled, alwaysAsk, disabled

        init(_ privateYoutubePlayerEnabled: Bool?) {
            switch privateYoutubePlayerEnabled {
            case true:
                self = .enabled
            case false:
                self = .disabled
            default:
                self = .alwaysAsk
            }
        }

        var boolValue: Bool? {
            switch self {
            case .enabled:
                return true
            case .alwaysAsk:
                return nil
            case .disabled:
                return false
            }
        }
    }

    @Published
    var isLoginDetectionEnabled: Bool {
        didSet {
            privacySecurityPreferences.loginDetectionEnabled = isLoginDetectionEnabled
        }
    }

    @Published
    var privatePlayerMode: PrivatePlayerMode {
        didSet {
            privacySecurityPreferences.privateYoutubePlayerEnabled = privatePlayerMode.boolValue
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
        privatePlayerMode = .init(privacySecurityPreferences.privateYoutubePlayerEnabled)
        isGPCEnabled = privacySecurityPreferences.gpcEnabled
        isAutoconsentEnabled = privacySecurityPreferences.autoconsentEnabled ?? false

        privacySecurityPreferences.$privateYoutubePlayerEnabled
            .map(PrivatePlayerMode.init)
            .removeDuplicates()
            .assign(to: \.privatePlayerMode, onWeaklyHeld: self)
            .store(in: &cancellables)

        privacySecurityPreferences.$gpcEnabled
            .removeDuplicates()
            .assign(to: \.isGPCEnabled, onWeaklyHeld: self)
            .store(in: &cancellables)
    }

    private let privacySecurityPreferences: PrivacySecurityPreferences
    private var cancellables: Set<AnyCancellable> = []
}
