//
//  ExperimentalFeatures.swift
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
import Foundation
import Persistence

protocol ExperimentalFeaturesPersistor {
    func value(for flag: FeatureFlag) -> Bool?
    func set(_ value: Bool?, for flag: FeatureFlag)
}

struct ExperimentalFeaturesUserDefaultsPersistor: ExperimentalFeaturesPersistor {
    let keyValueStore: KeyValueStoring

    func value(for flag: FeatureFlag) -> Bool? {
        let key = key(for: flag)
        return keyValueStore.object(forKey: key) as? Bool
    }

    func set(_ value: Bool?, for flag: FeatureFlag) {
        let key = key(for: flag)
        keyValueStore.set(value, forKey: key)
    }

    private func key(for flag: FeatureFlag) -> String {
        return "local-override.\(flag.rawValue)"
    }
}

protocol ExperimentalFeaturesHandler {
    func flagDidChange(_ featureFlag: FeatureFlag, isEnabled: Bool)
}

struct ExperimentalFeaturesDefaultHandler: ExperimentalFeaturesHandler {
    func flagDidChange(_ featureFlag: FeatureFlag, isEnabled: Bool) {
        switch featureFlag {
        case .htmlNewTabPage:
            isHTMLNewTabPageEnabledDidChange(isEnabled)
        default:
            break
        }
    }

    private func isHTMLNewTabPageEnabledDidChange(_ isEnabled: Bool) {
        Task { @MainActor in
            WindowControllersManager.shared.mainWindowControllers.forEach { mainWindowController in
                if mainWindowController.mainViewController.tabCollectionViewModel.selectedTabViewModel?.tab.content == .newtab {
                    mainWindowController.mainViewController.browserTabViewController.refreshTab()
                }
            }
        }
    }
}

final class ExperimentalFeatures {

    let internalUserDecider: InternalUserDecider
    let featureFlagger: FeatureFlagger
    private var persistor: ExperimentalFeaturesPersistor
    private var actionHandler: ExperimentalFeaturesHandler

    init(
        internalUserDecider: InternalUserDecider,
        featureFlagger: FeatureFlagger,
        persistor: ExperimentalFeaturesPersistor = ExperimentalFeaturesUserDefaultsPersistor(keyValueStore: UserDefaults.appConfiguration),
        actionHandler: ExperimentalFeaturesHandler = ExperimentalFeaturesDefaultHandler()
    ) {
        self.internalUserDecider = internalUserDecider
        self.featureFlagger = featureFlagger
        self.persistor = persistor
        self.actionHandler = actionHandler
    }

    func toggleOverride(for featureFlag: FeatureFlag) {
        guard internalUserDecider.isInternalUser else {
            return
        }
        let currentValue = persistor.value(for: featureFlag) ?? false
        let newValue = !currentValue
        persistor.set(!currentValue, for: featureFlag)
        actionHandler.flagDidChange(featureFlag, isEnabled: newValue)
    }

    func override(for featureFlag: FeatureFlag) -> Bool? {
        guard internalUserDecider.isInternalUser else {
            return nil
        }
        switch featureFlag {
        case .htmlNewTabPage:
            return persistor.value(for: featureFlag)
        default:
            return nil
        }
    }

    func clearAllOverrides() {
        FeatureFlag.allCases.forEach { flag in
            guard let override = override(for: flag) else {
                return
            }
            persistor.set(nil, for: flag)
            let defaultValue = featureFlagger.isFeatureOn(flag)
            if defaultValue != override {
                actionHandler.flagDidChange(flag, isEnabled: defaultValue)
            }
        }
    }
}
