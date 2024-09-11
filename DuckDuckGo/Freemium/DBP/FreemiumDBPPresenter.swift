//
//  FreemiumDBPPresenter.swift
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

/// Conforming types provide functionality to show Freemium DBP
protocol FreemiumDBPPresenter {
    func showFreemiumDBP(didOnboard: Bool, windowControllerManager: WindowControllersManagerProtocol?)
}

/// Default implementation of `FreemiumDBPPresenter`
struct DefaultFreemiumDBPPresenter: FreemiumDBPPresenter {

    @MainActor
    /// Displays Freemium DBP
    /// If the `didOnboard` parameter is true, opens DBP directly
    /// If the `didOnboard` parameter is false, opens Freemium DBP onboarding
    /// - Parameter didOnboard: Bool indicating if the user has onboarded already
    func showFreemiumDBP(didOnboard: Bool, windowControllerManager: WindowControllersManagerProtocol? = nil) {

        let windowControllerManager = windowControllerManager ?? WindowControllersManager.shared

        if didOnboard {
            windowControllerManager.showTab(with: .dataBrokerProtection)
        } else  {
            // TODO: - Onboard (i.e Ts and Cs)
            showFreemiumDBPOnboarding()
        }
    }
}

private extension DefaultFreemiumDBPPresenter {

    @MainActor
    func showFreemiumDBPOnboarding() {
        // TODO: - Show onboarding if we decide to do this
    }
}
