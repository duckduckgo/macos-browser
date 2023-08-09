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
            let isBold: Bool

            init(text: String, isBold: Bool = false) {
                self.text = text
                self.isBold = isBold
            }
        }

        private let step: OnboardingStep

        init(step: OnboardingStep) {
            self.step = step
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
                return "Step 1 of 2: Allow System Extension"
            case .userNeedsToAllowVPNConfiguration:
                return "Step 2 of 2: Add VPN Configuration"
            }
        }

        var description: [StyledTextFragment] {
            switch step {
            case .userNeedsToAllowExtension:
                return [
                    .init(text: "Open "),
                    .init(text: "System Settings", isBold: true),
                    .init(text: " to "),
                    .init(text: "Privacy & Security", isBold: true),
                    .init(text: ". Scroll and select "),
                    .init(text: "Allow", isBold: true),
                    .init(text: " for DuckDuckGo software.")
                ]
            case .userNeedsToAllowVPNConfiguration:
                return [
                    .init(text: "Select "),
                    .init(text: "Allow", isBold: true),
                    .init(text: " when prompted to finish setting up Network Protection.")
                ]
            }
        }

        var actionTitle: String {
            switch step {
            case .userNeedsToAllowExtension:
                return "Open System Settings..."
            case .userNeedsToAllowVPNConfiguration:
                return "Add VPN Configuration..."
            }
        }

        var actionScreenshot: NetworkProtectionAsset? {
            switch step {
            case .userNeedsToAllowExtension:
                return .allowSysexScreenshot
            case .userNeedsToAllowVPNConfiguration:
                return nil
            }
        }

        var action: (() -> Void) {
            switch step {
            case .userNeedsToAllowExtension:
                return {
                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Security")!
                    NSWorkspace.shared.open(url)
                }
            case .userNeedsToAllowVPNConfiguration:
                return {
                    print("Allow configuration clicked")
                }
            }
        }
    }
}
