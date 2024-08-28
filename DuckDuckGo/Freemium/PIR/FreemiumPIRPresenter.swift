//
//  FreemiumPIRPresenter.swift
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

/// Conforming types provide functionality to show Freemium PIR
protocol FreemiumPIRPresenter {
    func showFreemiumPIR(didOnboard: Bool, windowControllerManager: WindowControllersManagerProtocol?)
}

/// Default implementation of `FreemiumPIRPresenter`
struct DefaultFreemiumPIRPresenter: FreemiumPIRPresenter {

    @MainActor
    /// Displays Freemium PIR
    /// If the `didOnboard` parameter is true, opens PIR directly
    /// If the `didOnboard` parameter is false, opens Freemium PIR onboarding
    /// - Parameter didOnboard: Bool indicating if the user has onboarded already
    func showFreemiumPIR(didOnboard: Bool, windowControllerManager: WindowControllersManagerProtocol? = nil) {

        let windowControllerManager = windowControllerManager ?? WindowControllersManager.shared

        if didOnboard {
            windowControllerManager.showTab(with: .dataBrokerProtection)
        } else  {
            // TODO: - Onboard (i.e Ts and Cs)
            showFreemiumPIROnboarding()
        }
    }
}

private extension DefaultFreemiumPIRPresenter {

    @MainActor
    func showFreemiumPIROnboarding() {
        // TODO: - Show onboarding if we decide to do this
    }
}
