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

struct PermissionAuthorizationQueryInfo {
    let url: URL?
    let domain: String
    let permissions: [PermissionType]
    var wasShownOnce: Bool = false
    var shouldShowAlwaysAllowCheckbox: Bool = false
    var shouldShowCancelInsteadOfDeny: Bool = false
}
typealias PermissionAuthorizationQueryOutput = (granted: Bool, remember: Bool?)

typealias PermissionAuthorizationQuery = UserDialogRequest<PermissionAuthorizationQueryInfo, PermissionAuthorizationQueryOutput>
extension PermissionAuthorizationQuery {
    typealias Decision = Output

    var url: URL? { parameters.url }
    var domain: String { parameters.domain }
    var permissions: [PermissionType] { parameters.permissions }
    var wasShownOnce: Bool {
        get { parameters.wasShownOnce }
        set { parameters.wasShownOnce = newValue }
    }
    var shouldShowAlwaysAllowCheckbox: Bool {
        get { parameters.shouldShowAlwaysAllowCheckbox }
        set { parameters.shouldShowAlwaysAllowCheckbox = newValue }
    }
    var shouldShowCancelInsteadOfDeny: Bool {
        get { parameters.shouldShowCancelInsteadOfDeny }
        set { parameters.shouldShowCancelInsteadOfDeny = newValue }
    }

    convenience init(domain: String, url: URL?, permissions: [PermissionType], decisionHandler: @escaping (CallbackResult) -> Void) {
        self.init(.init(url: url, domain: domain, permissions: permissions), callback: decisionHandler)
    }

    func handleDecision(grant: Bool, remember: Bool? = nil) {
        self.submit( (granted: grant, remember: remember) )
    }

}
