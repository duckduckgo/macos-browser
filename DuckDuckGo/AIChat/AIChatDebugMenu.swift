//
//  AIChatDebugMenu.swift
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

final class AIChatDebugMenu: NSMenu {
    init() {
        super.init(title: "")

        buildItems {
            NSMenuItem(title: "Reset toolbar onboarding", action: #selector(resetToolbarOnboarding), target: self)
            NSMenuItem(title: "Show toolbar onboarding", action: #selector(showToolbarOnboarding), target: self)
        }
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func resetToolbarOnboarding() {
        DefaultAIChatPreferencesStorage().reset()
    }

    @objc func showToolbarOnboarding() {
        var storage = DefaultAIChatPreferencesStorage()
        storage.didDisplayAIChatToolbarOnboarding = false
        NotificationCenter.default.post(name: .AIChatOpenedForReturningUser, object: nil)
    }
}
