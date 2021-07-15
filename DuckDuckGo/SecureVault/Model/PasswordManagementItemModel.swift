//
//  PasswordManagementItemModel.swift
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

import Combine
import BrowserServicesKit

final class PasswordManagementItemModel: ObservableObject {

    static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        return dateFormatter
    } ()

    var onEditBegan: () -> Void
    var onSave: (SecureVaultModels.WebsiteCredentials) -> Void

    var credentials: SecureVaultModels.WebsiteCredentials? {
        didSet {
            title = credentials?.account.domain ?? ""
            username = credentials?.account.username ?? ""
            password = String(data: credentials?.password ?? Data(), encoding: .utf8) ?? ""
            domain = credentials?.account.domain ?? ""

            if let date = credentials?.account.created {
                createdDate = Self.dateFormatter.string(from: date)
            } else {
                createdDate = ""
            }

            if let date = credentials?.account.lastUpdated {
                lastUpdatedDate = Self.dateFormatter.string(from: date)
            } else {
                lastUpdatedDate = ""
            }
        }
    }

    @Published var title: String = ""
    @Published var username: String = ""
    @Published var password: String = ""

    var domain: String = ""
    var lastUpdatedDate: String = ""
    var createdDate: String = ""

    init(onEditBegan: @escaping () -> Void, onSave: @escaping (SecureVaultModels.WebsiteCredentials) -> Void) {
        self.onEditBegan = onEditBegan
        self.onSave = onSave
    }

}
