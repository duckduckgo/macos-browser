//
//  ExperimentalFeaturesMenu.swift
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

import AppKit
import FeatureFlags

struct FeatureFlagOverridesDefaultHandler: FeatureFlagOverridesHandler {
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


final class FeatureFlagOverridesMenu: NSMenu {

    let featureFlagger: OverridableFeatureFlagger

    private(set) lazy var htmlNewTabPageMenuItem = NSMenuItem(title: "HTML New Tab Page", action: #selector(toggleHTMLNewTabPage(_:))).targetting(self)

    init(featureFlagOverrides: OverridableFeatureFlagger) {
        self.featureFlagger = featureFlagOverrides
        super.init(title: "")

        buildItems {
            htmlNewTabPageMenuItem
            NSMenuItem.separator()
            NSMenuItem(title: "Reset All Overrides", action: #selector(resetAllOverrides(_:))).targetting(self)
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func update() {
        super.update()
        let featureFlagger = featureFlagger

        let isHTMLNTPOn = featureFlagger.isFeatureOn(.htmlNewTabPage, allowOverride: false)
        htmlNewTabPageMenuItem.title = "HTML New Tab Page (default: \(isHTMLNTPOn ? "on" : "off"))"
        htmlNewTabPageMenuItem.state = featureFlagger.isFeatureOn(.htmlNewTabPage) ? .on : .off
    }

    @objc func toggleHTMLNewTabPage(_ sender: NSMenuItem) {
        featureFlagger.overrides.toggleOverride(for: .htmlNewTabPage)
    }

    @objc func resetAllOverrides(_ sender: NSMenuItem) {
        featureFlagger.overrides.clearAllOverrides()
    }
}
