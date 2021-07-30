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
    let domain: String
    let permissions: [PermissionType]

    enum Decision {
        case granted(PermissionAuthorizationQuery)
        case denied(PermissionAuthorizationQuery)
        case deinitialized
    }
    private var decisionHandler: ((Decision) -> Void)?

    init(domain: String, permissions: [PermissionType], decisionHandler: @escaping (Decision) -> Void) {
        self.domain = domain
        self.permissions = permissions
        self.decisionHandler = decisionHandler
    }

    func handleDecision(grant: Bool) {
        decisionHandler?(grant ? .granted(self) : .denied(self))
        decisionHandler = nil
    }

    deinit {
        decisionHandler?(.deinitialized)
    }

}
