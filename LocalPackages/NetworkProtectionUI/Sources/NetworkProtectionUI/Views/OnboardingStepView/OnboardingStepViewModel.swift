//
//  OnboardingStepViewModel.swift
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

extension OnboardingStepView {

    /// Model for AllowSystemExtensionView
    ///
    final class Model: ObservableObject {
        struct StyledTextFragment {
            let text: String
            let isEmphasized: Bool

            init(text: String, isEmphasized: Bool = false) {
                self.text = text
                self.isEmphasized = isEmphasized
            }
        }

        private let step: OnboardingStep
        let action: () -> Void

        init(step: OnboardingStep, action: @escaping () -> Void) {
            self.step = step
            self.action = action
        }

        var icon: NetworkProtectionAsset {
            switch step {
            case .userNeedsToAllowExtension:
                return .appleVaultIcon
            case .userNeedsToAllowVPNConfiguration:
                return .appleVPNIcon
            }
        }

        var title: String {
            switch step {
            case .userNeedsToAllowExtension:
                return UserText.networkProtectionOnboardingAllowExtensionTitle
            case .userNeedsToAllowVPNConfiguration:
                return UserText.networkProtectionOnboardingAllowVPNTitle
            }
        }

        var description: [StyledTextFragment] {
            switch step {
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
            switch step {
            case .userNeedsToAllowExtension:
                return UserText.networkProtectionOnboardingAllowExtensionAction
            case .userNeedsToAllowVPNConfiguration:
                return UserText.networkProtectionOnboardingAllowVPNAction
            }
        }

        var actionScreenshot: NetworkProtectionAsset? {
            switch step {
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
}
