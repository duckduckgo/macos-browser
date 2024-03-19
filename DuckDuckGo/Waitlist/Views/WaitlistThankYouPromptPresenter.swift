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

import Foundation

final class WaitlistThankYouPromptPresenter {

    private enum Constants {
        static let didShowThankYouPromptKey = "duckduckgo.macos.browser.did-show-thank-you-prompt"
    }

    private let isVPNBetaTester: () -> Bool
    private let isPIRBetaTester: () -> Bool
    private let userDefaults: UserDefaults

    convenience init() {
        self.init(isVPNBetaTester: {
            return false
        }, isPIRBetaTester: {
            return false
        })
    }

    init(isVPNBetaTester: @escaping () -> Bool, isPIRBetaTester: @escaping () -> Bool, userDefaults: UserDefaults = .standard) {
        self.isVPNBetaTester = isVPNBetaTester
        self.isPIRBetaTester = isPIRBetaTester
        self.userDefaults = userDefaults
    }

    // Presents a Thank You prompt to testers of the VPN or PIR.
    // If the user tested both, the PIR prompt will be displayed.
    @MainActor
    func presentThankYouPromptIfNecessary(in window: NSWindow) {
        guard canShowPromptCheck() else {
            return
        }

        if isPIRBetaTester() {
            presentPIRThankYouPrompt(in: window)
            saveDidShowPromptCheck()
        }

        if isVPNBetaTester() {
            presentVPNThankYouPrompt(in: window)
            saveDidShowPromptCheck()
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

    func canShowPromptCheck() -> Bool {
        return !self.userDefaults.bool(forKey: Constants.didShowThankYouPromptKey)
    }

    func resetPromptCheck() {
        self.userDefaults.removeObject(forKey: Constants.didShowThankYouPromptKey)
    }

    private func saveDidShowPromptCheck() {
        self.userDefaults.setValue(true, forKey: Constants.didShowThankYouPromptKey)
    }

}
