//
//  PasswordManagerSettings.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

final class PasswordManagerSettings {

    @UserDefaultsWrapper(key: .passwordManagerDoNotPromptDomains, defaultValue: [])
    private(set) var doNotPromptDomains: [String]

    func doNotPromptOnDomain(_ domain: String) {
        doNotPromptDomains.append(domain)
        doNotPromptDomains = [String](Set<String>(doNotPromptDomains))
    }

    func canPromptOnDomain(_ domain: String) -> Bool {
        let doNotPrompt = doNotPromptDomains.contains(domain) || doNotPromptDomains.contains(domain.dropWWW())
        return !doNotPrompt
    }

}
