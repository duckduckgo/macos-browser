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

final class DuckPlayerOnboardingTabExtension: TabExtension {
    @Published private(set) var shouldShowBanner: Bool?
}

extension DuckPlayerOnboardingTabExtension: NavigationResponder {

    @MainActor
    func decidePolicy(for navigationAction: NavigationAction, preferences: inout NavigationPreferences) async -> NavigationActionPolicy? {

        if navigationAction.url.absoluteString == "https://www.youtube.com/" {
            shouldShowBanner = true
            return .allow
        }
        return .allow
    }
}

protocol DuckPlayerOnboardingProtocol: AnyObject, NavigationResponder {
    var duckPlayerOnboardingPublisher: AnyPublisher<Bool?, Never>  { get }
}

extension DuckPlayerOnboardingTabExtension: DuckPlayerOnboardingProtocol {
    func getPublicProtocol() -> DuckPlayerOnboardingProtocol { self }

    var duckPlayerOnboardingPublisher: AnyPublisher<Bool?, Never> {
        self.$shouldShowBanner.eraseToAnyPublisher()
    }
}

extension TabExtensions {
    var duckPlayerOnboarding: DuckPlayerOnboardingProtocol? {
        resolve(DuckPlayerOnboardingTabExtension.self)
    }
}

extension Tab {
    var duckPlayerOnboardingPublisher: AnyPublisher<Bool?, Never> {
        self.duckPlayerOnboarding?.duckPlayerOnboardingPublisher ?? Just(nil).eraseToAnyPublisher()
    }
}
