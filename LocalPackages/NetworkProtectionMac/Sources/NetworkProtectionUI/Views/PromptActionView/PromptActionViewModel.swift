//
//  PromptActionViewModel.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import Foundation

extension PromptActionView {

    /// Model for AllowSystemExtensionView
    ///
    final class Model: ObservableObject {

        private(set) var icon: NetworkProtectionAsset
        private(set) var title: String
        private(set) var description: [StyledTextFragment]
        private(set) var actionTitle: String
        private(set) var actionScreenshot: NetworkProtectionAsset?
        let action: () -> Void

        convenience init(onboardingStep: OnboardingStep, isMenuBar: Bool, action: @escaping () -> Void) {
            self.init(
                icon: onboardingStep.icon,
                title: onboardingStep.title,
                description: onboardingStep.description(isMenuBar: isMenuBar),
                actionTitle: onboardingStep.actionTitle,
                actionScreenshot: onboardingStep.actionScreenshot,
                action: action
            )
        }

        convenience init(presentationData data: PromptPresentable, action: @escaping () -> Void) {
            self.init(
                icon: data.icon,
                title: data.title,
                description: data.description,
                actionTitle: data.actionTitle,
                actionScreenshot: data.actionScreenshot,
                action: action
            )
        }

        init(icon: NetworkProtectionAsset,
             title: String,
             description: [StyledTextFragment],
             actionTitle: String,
             actionScreenshot: NetworkProtectionAsset? = nil,
             action: @escaping () -> Void) {
            self.icon = icon
            self.title = title
            self.description = description
            self.actionTitle = actionTitle
            self.actionScreenshot = actionScreenshot
            self.action = action
        }
    }
}

protocol PromptPresentable {
    var icon: NetworkProtectionAsset { get }

    var title: String { get }

    var description: [StyledTextFragment] { get }

    var actionTitle: String { get }

    var actionScreenshot: NetworkProtectionAsset? { get }
}

struct StyledTextFragment {
    let text: String
    let isEmphasized: Bool

    init(text: String, isEmphasized: Bool = false) {
        self.text = text
        self.isEmphasized = isEmphasized
    }
}

extension OnboardingStep {
    var icon: NetworkProtectionAsset {
        switch self {
        case .userNeedsToAllowExtension:
            return .appleVaultIcon
        case .userNeedsToAllowVPNConfiguration:
            return .appleVPNIcon
        }
    }

    var title: String {
        switch self {
        case .userNeedsToAllowExtension:
            return UserText.networkProtectionOnboardingInstallExtensionTitle
        case .userNeedsToAllowVPNConfiguration:
            return UserText.networkProtectionOnboardingAllowVPNTitle
        }
    }

    func description(isMenuBar: Bool) -> [StyledTextFragment] {
        switch self {
        case .userNeedsToAllowExtension:
            if #available(macOS 15, *) {
                return [
                    .init(text: UserText.networkProtectionOnboardingAllowExtensionDescPrefixForSequoia),
                    .init(text: UserText.networkProtectionOnboardingAllowExtensionDescEmphasized, isEmphasized: true),
                    .init(text: UserText.networkProtectionOnboardingAllowExtensionDescSuffixForSequoia),
                ]
            } else {
                return [
                    .init(text: UserText.networkProtectionOnboardingAllowExtensionDescPrefix),
                    .init(text: UserText.networkProtectionOnboardingAllowExtensionDescAllow, isEmphasized: true),
                    .init(text: UserText.networkProtectionOnboardingAllowExtensionDescSuffix),
                ]
            }
        case .userNeedsToAllowVPNConfiguration:
            if isMenuBar {
                return [
                    .init(text: UserText.networkProtectionOnboardingAllowVPNDescPrefix),
                    .init(text: UserText.networkProtectionOnboardingAllowVPNDescAllow, isEmphasized: true),
                    .init(text: UserText.networkProtectionOnboardingAllowVPNDescSuffix)
                ]
            } else {
                return [
                    .init(text: UserText.networkProtectionOnboardingAllowVPNDescPrefix),
                    .init(text: UserText.networkProtectionOnboardingAllowVPNDescAllow, isEmphasized: true),
                    .init(text: UserText.networkProtectionOnboardingAllowVPNDescExpandedSuffix)
                ]
            }
        }
    }

    var actionTitle: String {
        switch self {
        case .userNeedsToAllowExtension:
            return UserText.networkProtectionOnboardingAllowExtensionAction
        case .userNeedsToAllowVPNConfiguration:
            return UserText.networkProtectionOnboardingAllowVPNAction
        }
    }

    var actionScreenshot: NetworkProtectionAsset? {
        switch self {
        case .userNeedsToAllowExtension:
            if #available(macOS 15, *) {
                return .enableSysexImage
            } else if #available(macOS 12, *) {
                return .allowSysexScreenshot
            } else {
                return .allowSysexScreenshotBigSur
            }
        case .userNeedsToAllowVPNConfiguration:
            return nil
        }
    }
}

struct MoveToApplicationsPromptPresentationData: PromptPresentable {
    let icon: NetworkProtectionAsset = .appleApplicationsIcon

    let title: String = UserText.networkProtectionOnboardingMoveToApplicationsTitle

    let description: [StyledTextFragment] = [
        .init(text: UserText.networkProtectionOnboardingMoveToApplicationsDesc)
    ]

    let actionTitle: String = UserText.networkProtectionOnboardingMoveToApplicationsAction

    let actionScreenshot: NetworkProtectionAsset? = nil
}

struct LoginItemsPromptPresentationData: PromptPresentable {
    let icon: NetworkProtectionAsset = .appleSystemSettingsIcon
    let title: String = "Change System Setting To Reconnect"
    let description: [StyledTextFragment] = [
        .init(text: "Open "),
        .init(text: "System Settings", isEmphasized: true),
        .init(text: " and allow DuckDuckGo VPN to run in the background."),
    ]
    let actionTitle: String = "Open System Settings…"
    let actionScreenshot: NetworkProtectionAsset? = nil
}
