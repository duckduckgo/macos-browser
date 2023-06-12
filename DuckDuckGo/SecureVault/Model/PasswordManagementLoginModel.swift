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

    var onSaveRequested: (SecureVaultModels.WebsiteCredentials) -> Void
    var onDeleteRequested: (SecureVaultModels.WebsiteCredentials) -> Void
    var urlMatcher: AutofillUrlMatcher
    var emailManager: EmailManager

    var isEditingPublisher: Published<Bool>.Publisher {
        return $isEditing
    }

    var credentials: SecureVaultModels.WebsiteCredentials? {
        didSet {
            populateViewModelFromCredentials()
        }
    }

    @Published var title: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var domain: String = ""
    @Published var isEditing = false
    @Published var isNew = false

    var isDirty: Bool {
        username != "" || password != "" || domain != ""
    }

    var lastUpdatedDate: String = ""
    var createdDate: String = ""

    // MARK: Private Emaill Address Variables
    @Published var privateEmailRequestInProgress: Bool = false
    @Published var usernameIsPrivateEmail: Bool = false
    @Published var hasValidPrivateEmail: Bool = false
    @Published var privateEmailStatus: EmailAliasStatus = .unknown
    @Published var shouldConfirmPrivateEmailUpdate: Bool = false
    @Published var isShowingDuckRemovalAlert: Bool = false

    var userDuckAddress: String {
        return emailManager.userEmail ?? ""
    }

    var privateEmailMessage: String {
        var message: String
        switch privateEmailStatus {
        case .inactive:
        message = UserText.pmEmailMessageInactive
        case .notFound:
        message = UserText.pmEmailMessageNotAllowed
        case .error:
        message = UserText.pmEmailMessageError
        default:
        message = ""
        }
        return message
    }

    var toggleConfirmationAlert: (title: String, message: String, button: String, destructive: Bool) {
        if privateEmailStatus == .active {
            return (title: UserText.pmEmailDeactivateConfirmTitle,
                    message: UserText.pmEmailDeactivateConfirmContent,
                    button: UserText.pmDeactivate,
                    destructive: true)
        }
        return (title: UserText.pmEmailActivateConfirmContent,
                message: UserText.pmEmailActivateConfirmContent,
                button: UserText.pmActivate,
                destructive: false)
    }

    private var previousUsername: String = ""

    init(onSaveRequested: @escaping (SecureVaultModels.WebsiteCredentials) -> Void,
         onDeleteRequested: @escaping (SecureVaultModels.WebsiteCredentials) -> Void,
         urlMatcher: AutofillUrlMatcher = AutofillDomainNameUrlMatcher(),
         emailManager: EmailManager = EmailManager()) {
        self.onSaveRequested = onSaveRequested
        self.onDeleteRequested = onDeleteRequested
        self.urlMatcher = urlMatcher
        self.emailManager = emailManager
        self.emailManager.requestDelegate = self

    }

    func setSecureVaultModel<Model>(_ modelObject: Model) {
        guard let modelObject = modelObject as? SecureVaultModels.WebsiteCredentials else {
            return
        }

        credentials = modelObject
    }

    func clearSecureVaultModel() {
        credentials = nil
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
        hasValidPrivateEmail = emailManager.isPrivateEmail(email: username)
        onSaveRequested(credentials)
        if emailManager.isPrivateEmail(email: previousUsername) &&
            !hasValidPrivateEmail &&
            (privateEmailStatus == .active || privateEmailStatus == .inactive) {
            isShowingDuckRemovalAlert = true
        }
    }

    func requestDelete() {
        guard let credentials = credentials else { return }
        onDeleteRequested(credentials)
    }

    func edit() {
        previousUsername = username
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

    @MainActor
    func openURL(_ url: URL) {
        WindowControllersManager.shared.show(url: url, newTab: true)
    }

    func confirmPrivateEmailStatusUpdate() {
        shouldConfirmPrivateEmailUpdate = true
    }

    func togglePrivateEmailStatus() {
        Task { try await togglePrivateEmailStatus() }
    }

    private func populateViewModelFromCredentials() {
        let titleString = credentials?.account.title ?? ""
        title = titleString
        username = credentials?.account.username ?? ""
        password = String(data: credentials?.password ?? Data(), encoding: .utf8) ?? ""
        domain =  urlMatcher.normalizeUrlForWeb(credentials?.account.domain ?? "")
        isNew = credentials?.account.id == nil

        // Determine Private Email Status when required
        usernameIsPrivateEmail = emailManager.isPrivateEmail(email: username)
        if usernameIsPrivateEmail {
            Task { try? await getPrivateEmailStatus() }
        }

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

    private func getPrivateEmailStatus() async throws {
        guard emailManager.isSignedIn else {
            throw AliasRequestError.signedOut
        }

        guard username != "",
              emailManager.isPrivateEmail(email: username) else {
            throw AliasRequestError.notFound
        }

        do {
            await setLoadingStatus(true)
            let result = try await emailManager.getStatusFor(email: username)
            await setLoadingStatus(false)
            await setPrivateEmailStatus(result)
        } catch {
            await setLoadingStatus(false)
            await setPrivateEmailStatus(.error)
        }
    }

    private func togglePrivateEmailStatus() async throws {
        guard emailManager.isSignedIn else {
            throw AliasRequestError.signedOut
        }

        guard username != "",
              emailManager.isPrivateEmail(email: username) else {
            throw AliasRequestError.notFound
        }
        do {
            await setLoadingStatus(true)
            var result: EmailAliasStatus
            if privateEmailStatus == .active {
                result = try await emailManager.setStatusFor(email: username, active: false)
            } else {
                result = try await emailManager.setStatusFor(email: username, active: true)
            }
            await setPrivateEmailStatus(result)
            await setLoadingStatus(false)
        } catch {
            await setLoadingStatus(false)
            await setPrivateEmailStatus(.error)
        }

    }

    @MainActor
    private func setPrivateEmailStatus(_ status: EmailAliasStatus) {
        hasValidPrivateEmail = true
        privateEmailStatus = status
    }

    @MainActor
    private func setLoadingStatus(_ status: Bool) {
        privateEmailRequestInProgress = status
    }

}

extension PasswordManagementLoginModel: EmailManagerRequestDelegate {}
