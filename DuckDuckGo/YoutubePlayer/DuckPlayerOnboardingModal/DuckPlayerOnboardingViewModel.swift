//
//  DuckPlayerOnboardingViewModel.swift
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

protocol DuckPlayerOnboardingViewModelDelegate: AnyObject {
    func duckPlayerOnboardingViewModelDidSelectTurnOn(_ viewModel: DuckPlayerOnboardingViewModel)
    func duckPlayerOnboardingViewModelDidSelectNotNow(_ viewModel: DuckPlayerOnboardingViewModel)
    func duckPlayerOnboardingViewModelDidSelectGotIt(_ viewModel: DuckPlayerOnboardingViewModel)
}

final class DuckPlayerOnboardingViewModel: ObservableObject {
    enum DuckPlayerModalCurrentView {
        case onboardingOptions
        case confirmation
    }

    @Published var currentView: DuckPlayerModalCurrentView = .onboardingOptions
    weak var delegate: DuckPlayerOnboardingViewModelDelegate?

    func handleTurnOnCTA() {
        delegate?.duckPlayerOnboardingViewModelDidSelectTurnOn(self)
    }

    func handleNotNowCTA() {
        delegate?.duckPlayerOnboardingViewModelDidSelectNotNow(self)
    }

    func handleGotItCTA() {
        delegate?.duckPlayerOnboardingViewModelDidSelectGotIt(self)
    }
}
