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
import BrowserServicesKit
import PixelKit

final class WaitlistThankYouPromptPresenter {

    private enum Constants {
        static let didShowThankYouPromptKey = "duckduckgo.macos.browser.did-show-thank-you-prompt"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Presentation

    // Presents a Thank You prompt to testers of PIR.
    // If the user tested both, the PIR prompt will be displayed.
    @MainActor
    func presentThankYouPromptIfNecessary(in window: NSWindow) {
        guard canShowPromptCheck() else {
            return
        }
    }

    // MARK: - Eligibility

    var canShowPIRCard: Bool {
        return false
    }

    func canShowPromptCheck() -> Bool {
        return !self.userDefaults.bool(forKey: Constants.didShowThankYouPromptKey)
    }

    // MARK: - Dismissal

    private func saveDidShowPromptCheck() {
        self.userDefaults.setValue(true, forKey: Constants.didShowThankYouPromptKey)
    }

    // MARK: - Debug

    func resetPromptCheck() {
        self.userDefaults.removeObject(forKey: Constants.didShowThankYouPromptKey)
    }

}
