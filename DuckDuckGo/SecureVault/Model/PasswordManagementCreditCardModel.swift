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
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        return dateFormatter
    } ()

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

    @Published var isEditing = false
    @Published var isNew = false

    @Published var title: String = "" {
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

    func createNew() {
        card = .init(title: "",
                     cardNumber: nil,
                     cardSecurityCode: nil,
                     expirationMonth: nil,
                     expirationYear: nil,
                     countryCode: nil,
                     postalCode: nil)

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
