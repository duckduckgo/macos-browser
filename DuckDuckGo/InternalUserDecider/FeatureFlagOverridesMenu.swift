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

final class FeatureFlagOverridesMenu: NSMenu {

    let featureFlagger: FeatureFlagger

    let setInternalUserStateItem: NSMenuItem = {
        let item = NSMenuItem(title: "Set Internal User State First")
        item.isEnabled = false
        return item
    }()

    init(featureFlagOverrides: FeatureFlagger) {
        self.featureFlagger = featureFlagOverrides
        super.init(title: "")

        buildItems {
            internalUserStateMenuItem()
            NSMenuItem.separator()
            featureFlagMenuItems()
            NSMenuItem.separator()
            experimentFeatureMenuItems()
            NSMenuItem.separator()
            resetAllOverridesMenuItem()
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Menu Item Builders

    private func internalUserStateMenuItem() -> NSMenuItem {
        return setInternalUserStateItem
    }

    private func featureFlagMenuItems() -> [NSMenuItem] {
        return FeatureFlag.allCases
            .filter { $0.supportsLocalOverriding && $0.cohortType == nil }
            .map { flag in
                NSMenuItem(
                    title: menuItemTitle(for: flag),
                    action: #selector(toggleFeatureFlag(_:)),
                    target: self,
                    representedObject: flag
                )
            }
    }

    private func experimentFeatureMenuItems() -> [NSMenuItem] {
        return FeatureFlag.allCases
            .filter { $0.supportsLocalOverriding && $0.cohortType != nil }
            .map { experiment in
                let experimentMenuItem = NSMenuItem(
                    title: menuItemTitle(for: experiment),
                    action: nil,
                    target: self,
                    representedObject: experiment
                )
                experimentMenuItem.submenu = cohortSubmenu(for: experiment)
                return experimentMenuItem
            }
    }

    private func resetAllOverridesMenuItem() -> NSMenuItem {
        return NSMenuItem(
            title: "Remove All Overrides",
            action: #selector(resetAllOverrides(_:)),
            target: self
        )
    }

    // MARK: - Menu Updates

    override func update() {
        super.update()

        items.forEach { item in
            guard let flag = item.representedObject as? FeatureFlag else { return }
            item.isHidden = !featureFlagger.internalUserDecider.isInternalUser
            item.title = menuItemTitle(for: flag)

            if flag.cohortType == nil {
                updateFeatureFlagItem(item, flag: flag)
            } else {
                updateExperimentFeatureItem(item, flag: flag)
            }
        }

        setInternalUserStateItem.isHidden = featureFlagger.internalUserDecider.isInternalUser
    }

    private func updateFeatureFlagItem(_ item: NSMenuItem, flag: FeatureFlag) {
        let override = featureFlagger.localOverrides?.override(for: flag)
        item.state = override == true ? .on : .off
        item.submenu = override != nil ? resetOverrideSubmenu(for: flag) : nil
    }

    private func updateExperimentFeatureItem(_ item: NSMenuItem, flag: FeatureFlag) {
        let override = featureFlagger.localOverrides?.experimentOverride(for: flag)
        item.state = override != nil ? .on : .off
        item.submenu = override != nil ? resetOverrideSubmenu(for: flag) : cohortSubmenu(for: flag)
    }

    // MARK: - Actions

    @objc func toggleFeatureFlag(_ sender: NSMenuItem) {
        guard let featureFlag = sender.representedObject as? FeatureFlag else { return }
        featureFlagger.localOverrides?.toggleOverride(for: featureFlag)
    }

    @objc func toggleExperimentFeatureFlag(_ sender: NSMenuItem) {
        guard let representedObject = sender.representedObject as? (FeatureFlag, String) else { return }
        let (experimentFeature, cohort) = representedObject
        featureFlagger.localOverrides?.setExperimentCohortOverride(for: experimentFeature, cohort: cohort)
    }

    @objc func resetOverride(_ sender: NSMenuItem) {
        guard let featureFlag = sender.representedObject as? FeatureFlag else { return }
        featureFlagger.localOverrides?.clearOverride(for: featureFlag)
    }

    @objc func resetAllOverrides(_ sender: NSMenuItem) {
        featureFlagger.localOverrides?.clearAllOverrides(for: FeatureFlag.self)
    }

    // MARK: - Helpers

    private func menuItemTitle(for flag: FeatureFlag) -> String {
        return "\(flag.rawValue) (default: \(defaultValue(for: flag)), override: \(overrideValue(for: flag)))"
    }

    private func cohortSubmenu(for experiment: FeatureFlag) -> NSMenu {
        let submenu = NSMenu()
        let cohorts = getCohorts(for: experiment)

        for cohort in cohorts {
            let cohortItem = NSMenuItem(
                title: "Cohort: \(cohort)",
                action: #selector(toggleExperimentFeatureFlag(_:)),
                target: self
            )
            cohortItem.representedObject = (experiment, cohort.rawValue)
            submenu.addItem(cohortItem)
        }

        return submenu
    }

    private func getCohorts<Flag: FeatureFlagDescribing>(for featureFlag: Flag) -> [any FlagCohort] {
        return featureFlag.cohortType?.cohorts ?? []
    }

    private func resetOverrideSubmenu(for flag: FeatureFlag) -> NSMenu {
        let submenu = NSMenu()
        submenu.addItem(NSMenuItem(
            title: "Remove Override",
            action: #selector(resetOverride(_:)),
            target: self,
            representedObject: flag
        ))
        return submenu
    }

    private func defaultValue(for flag: FeatureFlag) -> String {
        if flag.cohortType == nil {
            return featureFlagger.isFeatureOn(for: flag, allowOverride: false) ? "on" : "off"
        } else {
            return featureFlagger.localOverrides?.currentExperimentCohort(for: flag)?.rawValue ?? "unassigned"
        }
    }

    private func overrideValue(for flag: FeatureFlag) -> String {
        if flag.cohortType == nil {
            guard let override = featureFlagger.localOverrides?.override(for: flag) else {
                return "none"
            }
            return override ? "on" : "off"
        } else {
            guard let override = featureFlagger.localOverrides?.experimentOverride(for: flag) else {
                return "none"
            }
            return override
        }
    }
}
