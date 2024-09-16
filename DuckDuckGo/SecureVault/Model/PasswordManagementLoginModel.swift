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
import Common
import PixelKit

final class PasswordManagementLoginModel: ObservableObject, PasswordManagementItemModel {

    typealias Model = SecureVaultModels.WebsiteCredentials

    enum FieldType: String {
        case username
        case password
    }

    static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        return dateFormatter
    }()

    var onSaveRequested: (SecureVaultModels.WebsiteCredentials) -> Void
    var onDeleteRequested: (SecureVaultModels.WebsiteCredentials) -> Void
    var urlMatcher: AutofillDomainNameUrlMatcher
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
    @Published var notes: String = ""
    @Published var isEditing = false
    @Published var isNew = false
    @Published var domainTLD = ""

    var isDirty: Bool {
        title != "" || username != "" || password != "" || domain != "" || notes != ""
    }

    var lastUpdatedDate: String = ""
    var createdDate: String = ""

    // MARK: Private Email Management
    @Published var privateEmailRequestInProgress: Bool = false
    @Published var usernameIsPrivateEmail: Bool = false
    @Published var hasValidPrivateEmail: Bool = false
    @Published var privateEmailStatus: EmailAliasStatus = .unknown
    @Published var isShowingAddressUpdateConfirmAlert: Bool = false
    @Published var isShowingDuckRemovalAlert: Bool = false
    @Published var isSignedIn: Bool = false
    @Published var privateEmailStatusBool: Bool = false {
        didSet {
            let status = privateEmailStatus == .active ? true : false
            if status != privateEmailStatusBool {
                isShowingAddressUpdateConfirmAlert = true
            }
        }
    }

    var userDuckAddress: String {
        return emailManager.userEmail ?? ""
    }

    var privateEmailMessage: String {
        var message: String
        if isSignedIn {
            switch privateEmailStatus {
            case .error:
                message = UserText.pmEmailMessageError
            case .active:
                message = UserText.pmEmailMessageActive
            case .inactive:
                message = UserText.pmEmailMessageInactive
            case .notFound:
                message = ""
            default:
                message = ""
            }
        } else {
            message = UserText.pmSignInToManageEmail
        }
        return message
    }

    var toggleConfirmationAlert: (title: String, message: String, button: String) {
        if privateEmailStatus == .active {
            return (title: UserText.pmEmailDeactivateConfirmTitle,
                    message: String(format: UserText.pmEmailDeactivateConfirmContent, username),
                    button: UserText.pmDeactivate)
        }
        return (title: UserText.pmEmailActivateConfirmTitle,
                message: String(format: UserText.pmEmailActivateConfirmContent, username),
                button: UserText.pmActivate)
    }

    var shouldShowPrivateEmailToggle: Bool {
        hasValidPrivateEmail && (privateEmailStatus == .active || privateEmailStatus == .inactive)
    }

    var shouldShowPrivateEmailSignedOutMesage: Bool {
        usernameIsPrivateEmail && privateEmailMessage != ""
    }

    private let tld: TLD
    private let urlSort: AutofillDomainNameUrlSort
    private static let randomColorsCount = 15

    init(onSaveRequested: @escaping (SecureVaultModels.WebsiteCredentials) -> Void,
         onDeleteRequested: @escaping (SecureVaultModels.WebsiteCredentials) -> Void,
         urlMatcher: AutofillDomainNameUrlMatcher,
         emailManager: EmailManager,
         tld: TLD = ContentBlocking.shared.tld,
         urlSort: AutofillDomainNameUrlSort) {
        self.onSaveRequested = onSaveRequested
        self.onDeleteRequested = onDeleteRequested
        self.urlMatcher = urlMatcher
        self.emailManager = emailManager
        self.tld = tld
        self.urlSort = urlSort
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

    func copy(_ value: String, fieldType: FieldType? = nil) {
        NSPasteboard.general.copy(value)
        if let fieldType = fieldType {
            switch fieldType {
            case .username:
                PixelKit.fire(GeneralPixel.autofillManagementCopyUsername)
            case .password:
                PixelKit.fire(GeneralPixel.autofillManagementCopyPassword)
            }
        }
    }

    func save() {
        guard var credentials = credentials else { return }
        credentials.account.title = title
        credentials.account.username = username
        credentials.account.domain = urlMatcher.normalizeUrlForWeb(domain)
        credentials.account.notes = notes
        credentials.password = password.data(using: .utf8)! // let it crash?
        hasValidPrivateEmail = emailManager.isPrivateEmail(email: username)
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

    @MainActor
    func openURL(_ url: URL) {
        WindowControllersManager.shared.show(url: url, source: .bookmark, newTab: true)
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
        notes = credentials?.account.notes ?? ""
        isNew = credentials?.account.id == nil
        let name = credentials?.account.name(tld: tld, autofillDomainNameUrlMatcher: urlMatcher)
        domainTLD = tld.eTLDplus1(name) ?? credentials?.account.title ?? "#"

        // Determine Private Email Status when required
        usernameIsPrivateEmail = emailManager.isPrivateEmail(email: username)
        if emailManager.isSignedIn {
            isSignedIn = true
            if usernameIsPrivateEmail {
                Task { try? await getPrivateEmailStatus() }
            }
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

    func enableEmailProtection() {
        NSApp.sendAction(#selector(NSPopover.performClose(_:)), to: nil, from: nil)
        NSApp.sendAction(#selector(AppDelegate.navigateToPrivateEmail(_:)), to: nil, from: nil)
    }

    @MainActor
    private func setPrivateEmailStatus(_ status: EmailAliasStatus) {
        hasValidPrivateEmail = true
        privateEmailStatus = status
        privateEmailStatusBool = status == .active ? true : false
    }

    @MainActor
    private func setLoadingStatus(_ status: Bool) {
        if status == true {
            privateEmailRequestInProgress = true
        } else {
            privateEmailRequestInProgress = false
        }

    }

    func refreshprivateEmailStatusBool() {
        privateEmailStatusBool = privateEmailStatus == .active ? true : false
    }

    @objc func showLoader() {
        privateEmailRequestInProgress = true
    }

}

extension PasswordManagementLoginModel: EmailManagerRequestDelegate { }
