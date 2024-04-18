//
//  PasswordManagementCreditCardModel.swift
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

final class PasswordManagementCreditCardModel: ObservableObject, PasswordManagementItemModel {

    typealias Model = SecureVaultModels.CreditCard

    static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM, yyyy"
        return dateFormatter
    }()

    var onDirtyChanged: (Bool) -> Void
    var onSaveRequested: (Model) -> Void
    var onDeleteRequested: (Model) -> Void

    var isEditingPublisher: Published<Bool>.Publisher {
        return $isEditing
    }

    var card: SecureVaultModels.CreditCard? {
        didSet {
            populateViewModelFromCard()
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

    @Published var cardNumber: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var cardholderName: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var cardSecurityCode: String = "" {
        didSet {
            isDirty = true
        }
    }

    @Published var expirationMonth: Int? {
        didSet {
            isDirty = true
        }
    }

    @Published var expirationYear: Int? {
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
         onSaveRequested: @escaping (SecureVaultModels.CreditCard) -> Void,
         onDeleteRequested: @escaping (SecureVaultModels.CreditCard) -> Void) {
        self.onDirtyChanged = onDirtyChanged
        self.onSaveRequested = onSaveRequested
        self.onDeleteRequested = onDeleteRequested
    }

    func copy(_ value: String) {
        NSPasteboard.general.copy(value)
    }

    func createNew() {
        card = .init(title: "",
                     cardNumber: "",
                     cardholderName: nil,
                     cardSecurityCode: nil,
                     expirationMonth: nil,
                     expirationYear: nil)

        isEditing = true
    }

    func cancel() {
        populateViewModelFromCard()
        isEditing = false

        if isNew {
            card = nil
            isNew = false
        }
    }

    func save() {
        guard var card = card else { return }

        card.title = title
        card.cardNumberData = cardNumber.data(using: .utf8)!
        card.cardholderName = cardholderName
        card.cardSecurityCode = cardSecurityCode
        card.expirationMonth = expirationMonth
        card.expirationYear = expirationYear

        onSaveRequested(card)
    }

    func clearSecureVaultModel() {
        card = nil
    }

    func setSecureVaultModel<Model>(_ modelObject: Model) {
        guard let modelObject = modelObject as? SecureVaultModels.CreditCard else {
            return
        }

        card = modelObject
    }

    func requestDelete() {
        guard let card = card else { return }
        onDeleteRequested(card)
    }

    func edit() {
        isEditing = true
    }

    private func populateViewModelFromCard() {
        title = card?.title ?? ""
        cardNumber = card?.cardNumber ?? ""
        cardholderName = card?.cardholderName ?? ""
        cardSecurityCode = card?.cardSecurityCode ?? ""
        expirationMonth = card?.expirationMonth
        expirationYear = card?.expirationYear

        isDirty = false

        isNew = card?.id == nil

        if let date = card?.created {
            createdDate = Self.dateFormatter.string(from: date)
        } else {
            createdDate = ""
        }

        if let date = card?.lastUpdated {
            lastUpdatedDate = Self.dateFormatter.string(from: date)
        } else {
            lastUpdatedDate = ""
        }
    }

}
