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

    var onDirtyChanged: (Bool) -> Void
    var onSaveRequested: (SecureVaultModels.WebsiteCredentials) -> Void
    var onDeleteRequested: (SecureVaultModels.WebsiteCredentials) -> Void

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

    @Published var isEditing = false
    @Published var isNew = false

    @Published var twoFactorSecret: String?

    var isDirty = false {
        didSet {
            self.onDirtyChanged(isDirty)
        }
    }

    func normalizedDomain(_ domain: String) -> String {
        let trimmed = domain.trimmingWhitespaces()
        if !trimmed.starts(with: "https://") && !trimmed.starts(with: "http://") && trimmed.contains("://") {
            // Contains some other protocol, so don't mess with it
            return domain
        }

        let noSchemeOrWWW = domain.drop(prefix: "https://").drop(prefix: "http://").dropWWW()
        return URLComponents(string: "https://\(noSchemeOrWWW)")?.host ?? ""
    }

    var lastUpdatedDate: String = ""
    var createdDate: String = ""

    init(onDirtyChanged: @escaping (Bool) -> Void,
         onSaveRequested: @escaping (SecureVaultModels.WebsiteCredentials) -> Void,
         onDeleteRequested: @escaping (SecureVaultModels.WebsiteCredentials) -> Void) {
        self.onDirtyChanged = onDirtyChanged
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

    func presentTwoFactorSecretWindow() {
        let windowPresenter = TwoFactorCodeScannerWindow()
        windowPresenter.showScanner()

        // NotificationCenter.default.post(name: Notification.Name("Check2FA"), object: nil)
    }

    func save(twoFactorSecret: String) {
        guard var credentials = credentials else { return }
        credentials.account.twoFactorSecret = twoFactorSecret
        onSaveRequested(credentials)
    }

    func requestTwoFactorSecretDeletion() {
        guard var credentials = credentials else { return }
        credentials.account.twoFactorSecret = nil
        onSaveRequested(credentials)
    }

    func save() {
        guard var credentials = credentials else { return }
        credentials.account.title = title
        credentials.account.username = username
        credentials.account.domain = normalizedDomain(domain)
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

    private func populateViewModelFromCredentials() {
        title =  credentials?.account.title ?? ""
        username = credentials?.account.username ?? ""
        password = String(data: credentials?.password ?? Data(), encoding: .utf8) ?? ""
        domain = normalizedDomain(credentials?.account.domain ?? "")
        twoFactorSecret = credentials?.account.twoFactorSecret
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
