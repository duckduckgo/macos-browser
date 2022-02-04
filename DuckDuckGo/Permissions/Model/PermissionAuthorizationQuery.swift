//
//  PermissionAuthorizationQuery.swift
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

final class PermissionAuthorizationQuery {
    let url: URL?
    let domain: String
    let permissions: [PermissionType]
    var wasShownOnce: Bool = false
    var shouldShowRememberChoiceCheckbox: Bool = false

    enum Decision {
        case granted(PermissionAuthorizationQuery)
        case denied(PermissionAuthorizationQuery)
        case deinitialized
    }
    private var decisionHandler: ((Decision, Bool?) -> Void)?

    init(domain: String, url: URL?, permissions: [PermissionType], decisionHandler: @escaping (Decision, Bool?) -> Void) {
        self.domain = domain
        self.url = url
        self.permissions = permissions
        self.decisionHandler = decisionHandler
    }

    func handleDecision(grant: Bool, remember: Bool? = nil) {
        decisionHandler?(grant ? .granted(self) : .denied(self), remember)
        decisionHandler = nil
    }

    deinit {
        decisionHandler?(.deinitialized, nil)
    }

}
