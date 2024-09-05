//
//  DuckPlayerPreferences.swift
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
import BrowserServicesKit
import PixelKit
import DuckPlayer

protocol DuckPlayerPreferencesPersistor {
    /// The persistor hadles raw Bool values but each one translates into a DuckPlayerMode:
    /// nil = .alwaysAsk,  false = .disabled, true = .enabled
    /// DuckPlayerMode init takes a Bool and returns the corresponding mode
    var duckPlayerModeBool: Bool? { get set }
    var youtubeOverlayInteracted: Bool { get set }
    var youtubeOverlayAnyButtonPressed: Bool { get set }
    var duckPlayerAutoplay: Bool { get set }
    var duckPlayerOpenInNewTab: Bool { get set }
}

struct DuckPlayerPreferencesUserDefaultsPersistor: DuckPlayerPreferencesPersistor {

    @UserDefaultsWrapper(key: .duckPlayerMode, defaultValue: nil)
    var duckPlayerModeBool: Bool?

    @UserDefaultsWrapper(key: .youtubeOverlayInteracted, defaultValue: false)
    var youtubeOverlayInteracted: Bool

    @UserDefaultsWrapper(key: .youtubeOverlayButtonsUsed, defaultValue: false)
    var youtubeOverlayAnyButtonPressed: Bool

    @UserDefaultsWrapper(key: .duckPlayerAutoplay, defaultValue: true)
    var duckPlayerAutoplay: Bool

    @UserDefaultsWrapper(key: .duckPlayerOpenInNewTab, defaultValue: true)
    var duckPlayerOpenInNewTab: Bool
}

final class DuckPlayerPreferences: ObservableObject {
    private let internalUserDecider: InternalUserDecider
    private let duckPlayerContingencyHandler: DuckPlayerContingencyHandler

    static let shared = DuckPlayerPreferences()
    private let privacyConfigurationManager: PrivacyConfigurationManaging

    @Published
    var duckPlayerMode: DuckPlayerMode {
        didSet {
            persistor.duckPlayerModeBool = duckPlayerMode.boolValue
        }
    }

    @Published
    var duckPlayerAutoplay: Bool {
        didSet {
            persistor.duckPlayerAutoplay = duckPlayerAutoplay
            if duckPlayerAutoplay {
                PixelKit.fire(NonStandardEvent(GeneralPixel.duckPlayerAutoplaySettingsOn))
            } else {
                PixelKit.fire(NonStandardEvent(GeneralPixel.duckPlayerAutoplaySettingsOff))
            }
        }
    }

    @Published
    var duckPlayerOpenInNewTab: Bool {
        didSet {
            persistor.duckPlayerOpenInNewTab = duckPlayerOpenInNewTab
            if duckPlayerOpenInNewTab {
                PixelKit.fire(NonStandardEvent(GeneralPixel.duckPlayerNewTabSettingsOn))
            } else {
                PixelKit.fire(NonStandardEvent(GeneralPixel.duckPlayerNewTabSettingsOff))
            }
        }
    }

    var shouldDisplayAutoPlaySettings: Bool {
        privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(DuckPlayerSubfeature.autoplay) || internalUserDecider.isInternalUser
    }

    var isOpenInNewTabSettingsAvailable: Bool {
        privacyConfigurationManager.privacyConfig.isSubfeatureEnabled(DuckPlayerSubfeature.openInNewTab) || internalUserDecider.isInternalUser
    }

    var isNewTabSettingsAvailable: Bool {
        duckPlayerMode != .disabled
    }

    var youtubeOverlayInteracted: Bool {
        didSet {
            persistor.youtubeOverlayInteracted = youtubeOverlayInteracted
        }
    }

    var youtubeOverlayAnyButtonPressed: Bool {
        didSet {
            persistor.youtubeOverlayAnyButtonPressed = youtubeOverlayAnyButtonPressed
        }
    }

    var shouldDisplayContingencyMessage: Bool {
        duckPlayerContingencyHandler.shouldDisplayContingencyMessage
    }

    func reset() {
        youtubeOverlayAnyButtonPressed = false
        youtubeOverlayInteracted = false
        duckPlayerMode = .alwaysAsk
        duckPlayerOpenInNewTab = true
        duckPlayerAutoplay = true
    }

    @MainActor
    func openLearnMoreContingencyURL() {
        guard let url = duckPlayerContingencyHandler.learnMoreURL else { return }
        PixelKit.fire(NonStandardEvent(GeneralPixel.duckPlayerContingencyLearnMoreClicked))
        WindowControllersManager.shared.show(url: url, source: .ui, newTab: true)
    }

    init(persistor: DuckPlayerPreferencesPersistor = DuckPlayerPreferencesUserDefaultsPersistor(),
         privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager,
         internalUserDecider: InternalUserDecider = NSApp.delegateTyped.internalUserDecider) {
        self.persistor = persistor
        duckPlayerMode = .init(persistor.duckPlayerModeBool)
        youtubeOverlayInteracted = persistor.youtubeOverlayInteracted
        youtubeOverlayAnyButtonPressed = persistor.youtubeOverlayAnyButtonPressed
        duckPlayerAutoplay = persistor.duckPlayerAutoplay
        duckPlayerOpenInNewTab = persistor.duckPlayerOpenInNewTab
        self.privacyConfigurationManager = privacyConfigurationManager
        self.internalUserDecider = internalUserDecider
        self.duckPlayerContingencyHandler = DefaultDuckPlayerContingencyHandler(privacyConfigurationManager: privacyConfigurationManager)
    }

    private var persistor: DuckPlayerPreferencesPersistor
    private var cancellables: Set<AnyCancellable> = []
}
