//
//  LoginImport.swift
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
import BrowserServicesKit

struct ImportedLoginCredential: Equatable {

    let title: String?
    let url: String?
    let username: String
    let password: String
    let notes: String?

    init(title: String? = nil, url: String?, username: String, password: String, notes: String? = nil) {
        self.title = title
        self.url = url.flatMap(URL.init(string:))?.host ?? url // Try to use the host if possible, as the Secure Vault saves credentials using the host.
        self.username = username
        self.password = password
        self.notes = notes
    }

}

protocol LoginImporter {

    func importLogins(_ logins: [ImportedLoginCredential]) throws -> DataImport.DataTypeSummary

}
