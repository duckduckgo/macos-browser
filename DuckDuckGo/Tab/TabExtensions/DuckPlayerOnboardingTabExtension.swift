//
//  DuckPlayerOnboardingTabExtension.swift
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
import Navigation
import Combine

typealias DuckPlayerOnboardingPublisher = AnyPublisher<OnboardingState?, Never>

final class DuckPlayerOnboardingTabExtension: TabExtension {
    @Published private(set) var onboardingState: OnboardingState?
    private let onboardingDecider: DuckPlayerOnboardingDecider

    init(onboardingDecider: DuckPlayerOnboardingDecider = DefaultDuckPlayerOnboardingDecider()) {
        self.onboardingDecider = onboardingDecider
    }
}

extension DuckPlayerOnboardingTabExtension: NavigationResponder {

    func navigationDidFinish(_ navigation: Navigation) {
        if navigation.url.absoluteString == "https://www.youtube.com/", onboardingDecider.canDisplayOnboarding {
            onboardingState = .init(onboardingDecider: onboardingDecider)
        }
    }
}

struct OnboardingState {
    let onboardingDecider: DuckPlayerOnboardingDecider
}

protocol DuckPlayerOnboardingProtocol: AnyObject, NavigationResponder {
    var duckPlayerOnboardingPublisher:DuckPlayerOnboardingPublisher  { get }
}

extension DuckPlayerOnboardingTabExtension: DuckPlayerOnboardingProtocol {
    func getPublicProtocol() -> DuckPlayerOnboardingProtocol { self }

    var duckPlayerOnboardingPublisher: DuckPlayerOnboardingPublisher {
        self.$onboardingState.eraseToAnyPublisher()
    }
}

extension TabExtensions {
    var duckPlayerOnboarding: DuckPlayerOnboardingProtocol? {
        resolve(DuckPlayerOnboardingTabExtension.self)
    }
}

extension Tab {
    var duckPlayerOnboardingPublisher:DuckPlayerOnboardingPublisher {
        self.duckPlayerOnboarding?.duckPlayerOnboardingPublisher ?? Just(nil).eraseToAnyPublisher()
    }
}
