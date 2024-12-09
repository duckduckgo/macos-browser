//
//  Tab+OnboardingNavigationDelegate.swift
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
import Onboarding

extension Tab: OnboardingNavigationDelegate {

    func searchFromOnboarding(for query: String) {
        // We check if the provided string is already a search query.
        // During onboarding, there's a specific case where we want to search for images,
        // and this allows us to handle that scenario.
        let url = if let url = URL(string: query), url.isDuckDuckGoSearch {
            url
        } else {
            URL.makeSearchUrl(from: query)
        }
        setUrl(url, source: .userEntered(query, downloadRequested: false))
    }

    func navigateFromOnboarding(to url: URL) {
        setUrl(url, source: .ui)
    }

}
