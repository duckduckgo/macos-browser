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

/// A manager for presenting the DuckPlayer onboarding modal.
///
/// The `DuckPlayerOnboardingModalManager` class is responsible for presenting the onboarding modal and handling its lifecycle.
///
final class DuckPlayerOnboardingModalManager {
    weak var currentTab: Tab?
    private(set) var modal: DuckPlayerOnboardingModal?
}

// MARK: - Public functions

extension DuckPlayerOnboardingModalManager {
    /**
     Shows the onboarding modal on the specified view.

     - Parameters:
       - view: The view on which to show the modal.
       - animated: A `Bool` indicating whether to animate the presentation.

     - Note: If the modal is already presented, this method does nothing.
     */
    func show(on view: NSView, animated: Bool) {
        prepareModal()
        guard let modal = modal else {
            return
        }

        modal.show(on: view, animated: animated)
    }

    /**
     Closes the onboarding modal and cleans up memory references.

     - Parameters:
       - animated: A `Bool` indicating whether to animate the dismissal.

     - Note: If the modal is not presented, this method does nothing.
     */
    func close(animated: Bool) {
        guard let modal = modal else {
            return
        }

        modal.close(animated: animated) { [weak self] in
            self?.cleanUp()
        }
    }

}

// MARK: - Private functions

extension DuckPlayerOnboardingModalManager {

    private func cleanUp() {
        self.modal = nil
        self.currentTab = nil
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

    func duckPlayerOnboardingModalDidFinish(_ modal: DuckPlayerOnboardingModal) {
        self.close(animated: true)
    }
}
