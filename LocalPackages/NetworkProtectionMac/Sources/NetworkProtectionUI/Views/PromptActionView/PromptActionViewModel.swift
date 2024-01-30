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

        private let presentationData: PromptPresentable
        let action: () -> Void

        init(presentationData: PromptPresentable, action: @escaping () -> Void) {
            self.presentationData = presentationData
            self.action = action
        }

        var icon: NetworkProtectionAsset {
            presentationData.icon
        }

        var title: String {
            presentationData.title
        }

        var description: [StyledTextFragment] {
            presentationData.description
        }

        var actionTitle: String {
            presentationData.actionTitle
        }

        var actionScreenshot: NetworkProtectionAsset? {
            presentationData.actionScreenshot
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

extension OnboardingStep: PromptPresentable {
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

    var description: [StyledTextFragment] {
        switch self {
        case .userNeedsToAllowExtension:
            return [
                .init(text: UserText.networkProtectionOnboardingAllowExtensionDescPrefix),
                .init(text: UserText.networkProtectionOnboardingAllowExtensionDescAllow, isEmphasized: true),
                .init(text: UserText.networkProtectionOnboardingAllowExtensionDescSuffix),
            ]
        case .userNeedsToAllowVPNConfiguration:
            return [
                .init(text: UserText.networkProtectionOnboardingAllowVPNDescPrefix),
                .init(text: UserText.networkProtectionOnboardingAllowVPNDescAllow, isEmphasized: true),
                .init(text: UserText.networkProtectionOnboardingAllowVPNDescSuffix),
            ]
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
            if #available(macOS 12, *) {
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
