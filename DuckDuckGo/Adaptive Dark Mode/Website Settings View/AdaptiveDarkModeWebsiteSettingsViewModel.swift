//
//  AdaptiveDarkModeWebsiteSettingsViewModel.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

final class AdaptiveDarkModeWebsiteSettingsViewModel: ObservableObject {
    let currentURL: URL

    @Published var isDarkModeEnabled: Bool = false
    
    var currentDomain: String {
        currentURL.host?.dropWWW() ?? ""
    }
    
    init(currentURL: URL) {
        self.currentURL = currentURL
    }
    
    func toggleDarkMode() {
        print("toggle dark mode")
    }
}
