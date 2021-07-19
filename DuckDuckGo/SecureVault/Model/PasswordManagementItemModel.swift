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

    var onEditChanged: (Bool) -> Void
    var onSaveRequested: (SecureVaultModels.WebsiteCredentials) -> Void
    var onDeleteRequested: (SecureVaultModels.WebsiteCredentials) -> Void

    var credentials: SecureVaultModels.WebsiteCredentials? {
        didSet {
            populateViewModelFromCredentials()
        }
    }

    @Published var title: String = ""
    @Published var username: String = ""
    @Published var password: String = ""

    @Published var isEditing = false {
        didSet {
            self.onEditChanged(isEditing)
        }
    }

    var domain: String = ""
    var lastUpdatedDate: String = ""
    var createdDate: String = ""

    init(onEditChanged: @escaping (Bool) -> Void,
         onSaveRequested: @escaping (SecureVaultModels.WebsiteCredentials) -> Void,
         onDeleteRequested: @escaping (SecureVaultModels.WebsiteCredentials) -> Void) {
        self.onEditChanged = onEditChanged
        self.onSaveRequested = onSaveRequested
        self.onDeleteRequested = onDeleteRequested
    }

    func copyPassword() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(password, forType: .string)
    }

    func copyUsername() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(username, forType: .string)
    }

    func save() {
        guard var credentials = credentials else { return }
        // TODO credentials.account.title = title
        credentials.account.username = username
        credentials.password = password.data(using: .utf8)! // let it crash?
        onSaveRequested(credentials)
    }

    func requestDelete() {
        guard let credentials = credentials else { return }
        onDeleteRequested(credentials)
    }

    func edit() {
        isEditing = true
    }

    func cancel() {
        populateViewModelFromCredentials()
        isEditing = false
    }

    func populateViewModelFromCredentials() {
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
