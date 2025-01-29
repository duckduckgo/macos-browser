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
            // Internal user state item
            internalUserStateMenuItem()

            // Separator
            NSMenuItem.separator()

            // Feature flag items
            featureFlagMenuItems()

            // Separator
            NSMenuItem.separator()

            // Experiment feature items
            experimentFeatureMenuItems()

            // Separator
            NSMenuItem.separator()

            // Reset all overrides
            resetAllOverridesMenuItem()
        }
    }

    private func internalUserStateMenuItem() -> NSMenuItem {
        return setInternalUserStateItem
    }

    private func experimentFeatureMenuItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        let experiments = FeatureFlag.allCases.filter { $0.supportsLocalOverriding && $0.cohortType != nil }
        for experiment in experiments {
            // Create main experiment menu item
            let experimentMenuItem = NSMenuItem(
                title: "Experiment \(experiment.rawValue): \(featureFlagger.localOverrides!.experimentOverride(for: experiment) ?? "Not Overridden")",
                action: nil,
                target: self,
                representedObject: experiment
            )

            // Retrieve the cohorts (check if this is valid)
            let cohorts = getCohorts(for: experiment)

            // Create submenu for cohorts
            let experimentSubMenu = NSMenu()
            for cohort in cohorts {
                let cohortMenuItem = NSMenuItem(
                    title: "Cohort: \(cohort)",
                    action: #selector(toggleExperimentFeatureFlag(_:)),
                    target: self
                )
                cohortMenuItem.representedObject = (experiment, cohort.rawValue)
                experimentSubMenu.addItem(cohortMenuItem)
            }

            experimentMenuItem.submenu = experimentSubMenu
            items.append(experimentMenuItem)
        }
        return items
    }

    private func featureFlagMenuItems() -> [NSMenuItem] {
        return FeatureFlag.allCases
            .filter { $0.supportsLocalOverriding && $0.cohortType == nil }
            .map { flag in
                NSMenuItem(
                    title: "\(flag.rawValue) (default: \(featureFlagger.isFeatureOn(for: flag, allowOverride: false) ? "on" : "off"))",
                    action: #selector(toggleFeatureFlag(_:)),
                    target: self,
                    representedObject: flag
                )
            }
    }

    private func resetAllOverridesMenuItem() -> NSMenuItem {
        return NSMenuItem(
            title: "Remove All Overrides",
            action: #selector(resetAllOverrides(_:)),
            target: self
        )
    }

    private func getCohorts<Flag: FeatureFlagDescribing>(for featureFlag: Flag) -> [any FlagCohort] {
        return featureFlag.cohortType?.cohorts ?? []
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func update() {
        super.update()

        items.forEach { item in
            if let flag = item.representedObject as? FeatureFlag {
                item.isHidden = !featureFlagger.internalUserDecider.isInternalUser
                item.title = "\(flag.rawValue) (default: \(defaultValue(for: flag)), override: \(overrideValue(for: flag)))"
                if flag.cohortType == nil {
                    let override = featureFlagger.localOverrides?.override(for: flag)
                    item.state = override == true ? .on : .off

                    if override != nil {
                        item.submenu = NSMenu(items: [
                            NSMenuItem(
                                title: "Remove Override",
                                action: #selector(resetOverride(_:)),
                                target: self,
                                representedObject: flag
                            )
                        ])
                    } else {
                        item.submenu = nil
                    }
                } else {
                    let override = featureFlagger.localOverrides?.experimentOverride(for: flag)
                    item.state = override != nil ? .on : .off
                    // Retrieve the cohorts (check if this is valid)
                    let cohorts = getCohorts(for: flag)

                    // Create submenus
                    if item.state == .on {
                        item.submenu = NSMenu(items: [
                            NSMenuItem(
                                title: "Remove Override",
                                action: #selector(resetOverride(_:)),
                                target: self,
                                representedObject: flag
                            )
                        ])
                    } else {
                        let experimentSubMenu = NSMenu()
                        for cohort in cohorts {
                            let cohortMenuItem = NSMenuItem(
                                title: "Cohort: \(cohort)",
                                action: #selector(toggleExperimentFeatureFlag(_:)),
                                target: self
                            )
                            cohortMenuItem.representedObject = (flag, cohort.rawValue)
                            experimentSubMenu.addItem(cohortMenuItem)
                            item.submenu = experimentSubMenu
                        }
                    }
                }
            }
        }

        setInternalUserStateItem.isHidden = featureFlagger.internalUserDecider.isInternalUser
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
}
