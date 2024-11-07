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

import Foundation

protocol ExperimentalFeaturesPersistor {
    var isHTMLNewTabPageEnabled: Bool { get set }
}

struct ExperimentalFeaturesUserDefaultsPersistor: ExperimentalFeaturesPersistor {
    @UserDefaultsWrapper(key: .htmlNewTabPage, defaultValue: false)
    var isHTMLNewTabPageEnabled: Bool
}

protocol ExperimentalFeaturesHandler {
    func isHTMLNewTabPageEnabledDidChange(_ isEnabled: Bool)
}

struct ExperimentalFeaturesDefaultHandler: ExperimentalFeaturesHandler {
    func isHTMLNewTabPageEnabledDidChange(_ isEnabled: Bool) {
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

    private var persistor: ExperimentalFeaturesPersistor
    private var actionHandler: ExperimentalFeaturesHandler

    init(
        persistor: ExperimentalFeaturesPersistor = ExperimentalFeaturesUserDefaultsPersistor(),
        actionHandler: ExperimentalFeaturesHandler = ExperimentalFeaturesDefaultHandler()
    ) {
        self.persistor = persistor
        self.actionHandler = actionHandler
    }

    var isHTMLNewTabPageEnabled: Bool {
        get {
            persistor.isHTMLNewTabPageEnabled
        }
        set {
            if newValue != persistor.isHTMLNewTabPageEnabled {
                persistor.isHTMLNewTabPageEnabled = newValue
                actionHandler.isHTMLNewTabPageEnabledDidChange(newValue)
            }
        }
    }
}
