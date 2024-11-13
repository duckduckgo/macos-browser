//
//  FeatureFlagOverridesMenu.swift
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
import BrowserServicesKit
import FeatureFlags

struct FeatureFlagOverridesDefaultHandler: FeatureFlagLocalOverridesHandler {
    func flagDidChange<Flag: FeatureFlagProtocol>(_ featureFlag: Flag, isEnabled: Bool) {
        guard let flag = featureFlag as? FeatureFlag else { return }
        switch flag {
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

    let featureFlagger: FeatureFlagger

    init(featureFlagOverrides: FeatureFlagger) {
        self.featureFlagger = featureFlagOverrides
        super.init(title: "")

        buildItems {
            FeatureFlag.allCases.filter(\.supportsLocalOverriding).map { flag in
                NSMenuItem(
                    title: "\(flag.rawValue) (default: \(featureFlagger.isFeatureOn(flag, allowOverride: false) ? "on" : "off"))",
                    action: #selector(toggleFeatureFlag(_:)),
                    target: self,
                    representedObject: flag
                )
                .submenu(NSMenu(items: [
                    NSMenuItem(
                        title: "Remove Override",
                        action: #selector(resetOverride(_:)),
                        target: self,
                        representedObject: flag
                    )
                ]))
            }
            NSMenuItem.separator()
            NSMenuItem(title: "Remove All Overrides", action: #selector(resetAllOverrides(_:))).targetting(self)
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func update() {
        super.update()

        items.forEach { item in
            guard let flag = item.representedObject as? FeatureFlag else {
                return
            }
            item.title = "\(flag.rawValue) (default: \(defaultValue(for: flag)), override: \(overrideValue(for: flag)))"
            item.state = featureFlagger.localOverrides?.override(for: flag) == true ? .on : .off
        }
    }

    private func defaultValue(for flag: FeatureFlag) -> String {
        featureFlagger.isFeatureOn(flag, allowOverride: false) ? "on" : "off"
    }

    private func overrideValue(for flag: FeatureFlag) -> String {
        guard let override = featureFlagger.localOverrides?.override(for: flag) else {
            return "none"
        }
        return override ? "on" : "off"
    }

    @objc func toggleFeatureFlag(_ sender: NSMenuItem) {
        guard let featureFlag = sender.representedObject as? FeatureFlag else { return }
        featureFlagger.localOverrides?.toggleOverride(for: featureFlag)
    }

    @objc func resetOverride(_ sender: NSMenuItem) {
        guard let featureFlag = sender.representedObject as? FeatureFlag else { return }
        featureFlagger.localOverrides?.clearOverride(for: featureFlag)
    }

    @objc func resetAllOverrides(_ sender: NSMenuItem) {
        featureFlagger.localOverrides?.clearAllOverrides(for: FeatureFlag.self)
    }
}
