//
//  PasswordManagementIdentityModel.swift
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

final class PasswordManagementIdentityModel: ObservableObject, PasswordManagementItemModel {

    typealias Model = SecureVaultModels.Identity

    static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter
    }()

    var onDirtyChanged: (Bool) -> Void
    var onSaveRequested: (SecureVaultModels.Identity) -> Void
    var onDeleteRequested: (SecureVaultModels.Identity) -> Void

    var isEditingPublisher: Published<Bool>.Publisher {
        return $isEditing
    }

    var identity: SecureVaultModels.Identity? {
        didSet {
            populateViewModelFromIdentity()
        }
    }

    var isInEditMode: Bool {
        return isEditing || isNew
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

    @Published var title: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var firstName: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var middleName: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var lastName: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var birthdayDay: Int? {
        didSet {
            isDirty = true
        }
    }

    @Published var birthdayMonth: Int? {
        didSet {
            isDirty = true
        }
    }

    @Published var birthdayYear: Int? {
        didSet {
            isDirty = true
        }
    }

    @Published var addressStreet: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var addressStreet2: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var addressCity: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var addressProvince: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var addressPostalCode: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var addressCountryCode: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var homePhone: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var mobilePhone: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var emailAddress: String = "" {
        didSet {
            isDirty = true
        }
    }

    var isDirty = false {
        didSet {
            self.onDirtyChanged(isDirty)
        }
    }

    var lastUpdatedDate: String = ""
    var createdDate: String = ""

    init(onDirtyChanged: @escaping (Bool) -> Void,
         onSaveRequested: @escaping (SecureVaultModels.Identity) -> Void,
         onDeleteRequested: @escaping (SecureVaultModels.Identity) -> Void) {
        self.onDirtyChanged = onDirtyChanged
        self.onSaveRequested = onSaveRequested
        self.onDeleteRequested = onDeleteRequested
    }

    func copy(_ value: String) {
        NSPasteboard.general.copy(value)
    }

    func createNew() {
        identity = SecureVaultModels.Identity()
        isEditing = true
    }

    func cancel() {
        populateViewModelFromIdentity()
        isEditing = false

        if isNew {
            identity = nil
            isNew = false
        }
    }

    func save() {
        guard var identity = identity else { return }

        identity.title = title
        identity.firstName = firstName
        identity.middleName = middleName
        identity.lastName = lastName
        identity.birthdayDay = birthdayDay
        identity.birthdayMonth = birthdayMonth
        identity.birthdayYear = birthdayYear

        identity.addressStreet = addressStreet
        identity.addressStreet2 = addressStreet2
        identity.addressCity = addressCity
        identity.addressProvince = addressProvince
        identity.addressPostalCode = addressPostalCode
        identity.addressCountryCode = addressCountryCode

        identity.homePhone = homePhone
        identity.mobilePhone = mobilePhone
        identity.emailAddress = emailAddress

        onSaveRequested(identity)
    }

    func clearSecureVaultModel() {
        identity = nil
    }

    func setSecureVaultModel<Model>(_ modelObject: Model) {
        guard let modelObject = modelObject as? SecureVaultModels.Identity else {
            return
        }

        identity = modelObject
    }

    func requestDelete() {
        guard let identity = identity else { return }
        onDeleteRequested(identity)
    }

    func edit() {
        isEditing = true
    }

    private func populateViewModelFromIdentity() {
        title = identity?.title ?? ""

        firstName = identity?.firstName ?? ""
        middleName = identity?.middleName ?? ""
        lastName = identity?.lastName ?? ""

        birthdayDay = identity?.birthdayDay
        birthdayMonth = identity?.birthdayMonth
        birthdayYear = identity?.birthdayYear

        addressStreet = identity?.addressStreet ?? ""
        addressStreet2 = identity?.addressStreet2 ?? ""
        addressCity = identity?.addressCity ?? ""
        addressProvince = identity?.addressProvince ?? ""
        addressPostalCode = identity?.addressPostalCode ?? ""
        addressCountryCode = identity?.addressCountryCode ?? ""

        homePhone = identity?.homePhone ?? ""
        mobilePhone = identity?.mobilePhone ?? ""
        emailAddress = identity?.emailAddress ?? ""

        isDirty = false

        isNew = identity?.id == nil

        if let date = identity?.created {
            createdDate = Self.dateFormatter.string(from: date)
        } else {
            createdDate = ""
        }

        if let date = identity?.lastUpdated {
            lastUpdatedDate = Self.dateFormatter.string(from: date)
        } else {
            lastUpdatedDate = ""
        }
    }

}
