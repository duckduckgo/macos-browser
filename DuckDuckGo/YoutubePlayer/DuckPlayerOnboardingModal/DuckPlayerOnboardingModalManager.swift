//
//  DuckPlayerOnboardingModalManager.swift
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

final class DuckPlayerOnboardingModalManager {
    var completion: ((Bool) -> Void)?
    weak var currentTab: Tab?

    private(set) var modal: DuckPlayerOnboardingModal?

    func cookieConsentPopover(_ modal: DuckPlayerOnboardingModal, didFinishWithResult result: Bool) {
        modal.close(animated: true) {
            withExtendedLifetime(modal) {}
        }
        self.modal = nil
        self.currentTab = nil

        if let completion = completion {
            completion(result)
        }
    }

    func show(on view: NSView, animated: Bool, result: ((Bool) -> Void)? = nil) {
        prepareModal()
        guard let modal = modal else {
            return
        }

        modal.show(on: view, animated: animated)
        if let result = result {
            self.completion = result
        }
    }

    func close(animated: Bool) {
        guard let modal = modal else {
            return
        }

        modal.close(animated: animated)
    }

    private func prepareModal() {
        // If the tab was closed, we want to start the animation again
        if currentTab == nil {
            modal = nil
        }

        guard modal == nil else {
            return
        }

        modal = DuckPlayerOnboardingModal()
        modal?.delegate = self
    }
}

extension DuckPlayerOnboardingModalManager: DuckPlayerOnboardingModalDelegate {
    func duckPlayerOnboardingModal(_ modal: DuckPlayerOnboardingModal, didFinishWithResult result: Bool) {
    }
}
