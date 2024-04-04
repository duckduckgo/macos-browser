//
//  WaitlistThankYouPromptPresenter.swift
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
import Foundation
import Subscription
import PixelKit

final class WaitlistThankYouPromptPresenter {

    private enum Constants {
        static let didShowThankYouPromptKey = "duckduckgo.macos.browser.did-show-thank-you-prompt"
        static let didDismissVPNCardKey = "duckduckgo.macos.browser.did-dismiss-vpn-card"
        static let didDismissPIRCardKey = "duckduckgo.macos.browser.did-dismiss-pir-card"
    }

    private let isVPNBetaTester: () -> Bool
    private let isPIRBetaTester: () -> Bool
    private let userDefaults: UserDefaults

    convenience init() {
        self.init(isVPNBetaTester: {
            return DefaultNetworkProtectionVisibility().isEligibleForThankYouMessage
        }, isPIRBetaTester: {
            return DefaultDataBrokerProtectionFeatureVisibility().isEligibleForThankYouMessage()
        })
    }

    init(isVPNBetaTester: @escaping () -> Bool, isPIRBetaTester: @escaping () -> Bool, userDefaults: UserDefaults = .standard) {
        self.isVPNBetaTester = isVPNBetaTester
        self.isPIRBetaTester = isPIRBetaTester
        self.userDefaults = userDefaults
    }

    // MARK: - Presentation

    // Presents a Thank You prompt to testers of the VPN or PIR.
    // If the user tested both, the PIR prompt will be displayed.
    @MainActor
    func presentThankYouPromptIfNecessary(in window: NSWindow) {
        // Wiring this here since it's mostly useful for rolling out PrivacyPro, and should
        // go away once PPro is fully rolled out.
        if DefaultSubscriptionFeatureAvailability().isFeatureAvailable {
            PixelKit.fire(PrivacyProPixel.privacyProFeatureEnabled, frequency: .dailyOnly)
        }

        guard canShowPromptCheck() else {
            return
        }

        if isPIRBetaTester() {
            saveDidShowPromptCheck()
            PixelKit.fire(PrivacyProPixel.privacyProBetaUserThankYouDBP, frequency: .dailyAndContinuous)
            presentPIRThankYouPrompt(in: window)
        } else if isVPNBetaTester() {
            saveDidShowPromptCheck()
            PixelKit.fire(PrivacyProPixel.privacyProBetaUserThankYouVPN, frequency: .dailyAndContinuous)
            presentVPNThankYouPrompt(in: window)
        }
    }

    @MainActor
    func presentVPNThankYouPrompt(in window: NSWindow) {
        let thankYouModalView = WaitlistBetaThankYouDialogViewController(copy: .vpn)
        let thankYouWindowController = thankYouModalView.wrappedInWindowController()
        if let thankYouWindow = thankYouWindowController.window {
            window.beginSheet(thankYouWindow)
        }
    }

    @MainActor
    func presentPIRThankYouPrompt(in window: NSWindow) {
        let thankYouModalView = WaitlistBetaThankYouDialogViewController(copy: .dbp)
        let thankYouWindowController = thankYouModalView.wrappedInWindowController()
        if let thankYouWindow = thankYouWindowController.window {
            window.beginSheet(thankYouWindow)
        }
    }

    // MARK: - Eligibility

    var canShowVPNCard: Bool {
        guard !self.userDefaults.bool(forKey: Constants.didDismissVPNCardKey) else {
            return false
        }

        return isVPNBetaTester()
    }

    var canShowPIRCard: Bool {
        guard !self.userDefaults.bool(forKey: Constants.didDismissPIRCardKey) else {
            return false
        }

        return isPIRBetaTester()
    }

    func canShowPromptCheck() -> Bool {
        return !self.userDefaults.bool(forKey: Constants.didShowThankYouPromptKey)
    }

    // MARK: - Dismissal

    func didDismissVPNThankYouCard() {
        self.userDefaults.setValue(true, forKey: Constants.didDismissVPNCardKey)
    }

    func didDismissPIRThankYouCard() {
        self.userDefaults.setValue(true, forKey: Constants.didDismissPIRCardKey)
    }

    private func saveDidShowPromptCheck() {
        self.userDefaults.setValue(true, forKey: Constants.didShowThankYouPromptKey)
    }

    // MARK: - Debug

    func resetPromptCheck() {
        self.userDefaults.removeObject(forKey: Constants.didShowThankYouPromptKey)
        self.userDefaults.removeObject(forKey: Constants.didDismissVPNCardKey)
        self.userDefaults.removeObject(forKey: Constants.didDismissPIRCardKey)
    }

}
