//
//  PasswordManagementLoginModel.swift
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

final class PasswordManagementLoginModel: ObservableObject, PasswordManagementItemModel {

    typealias Model = SecureVaultModels.WebsiteCredentials

    static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        return dateFormatter
    } ()

    var onDirtyChanged: (Bool) -> Void
    var onSaveRequested: (SecureVaultModels.WebsiteCredentials) -> Void
    var onDeleteRequested: (SecureVaultModels.WebsiteCredentials) -> Void
    var urlMatcher: AutofillUrlMatcher

    func setSecureVaultModel<Model>(_ modelObject: Model) {
        guard let modelObject = modelObject as? SecureVaultModels.WebsiteCredentials else {
            return
        }

        credentials = modelObject
    }

    func clearSecureVaultModel() {
        credentials = nil
    }

    var isEditingPublisher: Published<Bool>.Publisher {
        return $isEditing
    }

    var credentials: SecureVaultModels.WebsiteCredentials? {
        didSet {
            populateViewModelFromCredentials()
        }
    }

    @Published var title: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var username: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var password: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var domain: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var isEditing = false {
        didSet {
            // Experimental change suggested by the design team to mark an item as dirty as soon as it enters the editing state.
            if isEditing {
                isDirty = true
            }
        }
    }

    @Published var isNew = false

    var isDirty = false {
        didSet {
            self.onDirtyChanged(isDirty)
        }
    }

    var lastUpdatedDate: String = ""
    var createdDate: String = ""

    init(onDirtyChanged: @escaping (Bool) -> Void,
         onSaveRequested: @escaping (SecureVaultModels.WebsiteCredentials) -> Void,
         onDeleteRequested: @escaping (SecureVaultModels.WebsiteCredentials) -> Void,
         urlMatcher: AutofillUrlMatcher = AutofillDomainNameUrlMatcher()) {
        self.onDirtyChanged = onDirtyChanged
        self.onSaveRequested = onSaveRequested
        self.onDeleteRequested = onDeleteRequested
        self.urlMatcher = urlMatcher
    }

    func copy(_ value: String) {
        NSPasteboard.general.copy(value)
    }

    func save() {
        guard var credentials = credentials else { return }
        credentials.account.title = title
        credentials.account.username = username
        credentials.account.domain = urlMatcher.normalizeUrlForWeb(domain)
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

        if isNew {
            credentials = nil
            isNew = false
        }
    }

    func createNew() {
        credentials = .init(account: .init(username: "", domain: ""), password: Data())
        isEditing = true
    }

    func openURL(_ url: URL) {
        WindowControllersManager.shared.show(url: url, newTab: true)
    }

    private func populateViewModelFromCredentials() {
        let titleString = credentials?.account.title ?? ""
        title = titleString
        username = credentials?.account.username ?? ""
        password = String(data: credentials?.password ?? Data(), encoding: .utf8) ?? ""
        domain =  urlMatcher.normalizeUrlForWeb(credentials?.account.domain ?? "")
        isDirty = false
        isNew = credentials?.account.id == nil

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
