//
//  UserText+PasswordManager.swift
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

extension UserText {

    static let pmDelete = NSLocalizedString("pm.delete", value: "Delete", comment: "Delete button")
    static let pmCancel = NSLocalizedString("pm.cancel", value: "Cancel", comment: "Cancel button")
    static let pmSave = NSLocalizedString("pm.save", value: "Save", comment: "Save button")
    static let pmEdit = NSLocalizedString("pm.edit", value: "Edit", comment: "Edit button")

    static let pmUsername = NSLocalizedString("pm.username", value: "Username", comment: "Label for username edit field")
    static let pmPassword = NSLocalizedString("pm.password", value: "Password", comment: "Label for password edit field")
    static let pmWebsite = NSLocalizedString("pm.website", value: "Website", comment: "Label for website edit field")
    static let pmLoginAdded = NSLocalizedString("pm.added", value: "Added", comment: "Label for login added data")
    static let pmLoginLastUpdated = NSLocalizedString("pm.last.updated", value: "Last Updated", comment: "Label for last updated edit field")
    static let pmNewLogin = NSLocalizedString("pm.new.login", value: "New Login", comment: "Label for new login title")

    static let pmCardNumber = NSLocalizedString("pm.card.number", value: "Card Number", comment: "Label for card number title")
    static let pmCardholderName = NSLocalizedString("pm.card.cardholder-name", value: "Cardholder Name", comment: "Label for cardholder name title")
    static let pmCardVerificationValue = NSLocalizedString("pm.card.cvv", value: "CVV", comment: "Label for CVV title")
    static let pmCardExpiration = NSLocalizedString("pm.card.expiration-date", value: "Expiration Date", comment: "Label for expiration date title")

    static let pmIdentification = NSLocalizedString("pm.identification", value: "Identification", comment: "Label for identification title")
    static let pmFirstName = NSLocalizedString("pm.name.first", value: "First Name", comment: "Label for first name title")
    static let pmMiddleName = NSLocalizedString("pm.name.middle", value: "Middle Name", comment: "Label for middle name title")
    static let pmLastName = NSLocalizedString("pm.name.last", value: "Last Name", comment: "Label for last name title")

    static let pmAddressStreet = NSLocalizedString("pm.address.street", value: "Street", comment: "Label for street title")
    static let pmAddressCity = NSLocalizedString("pm.address.city", value: "City", comment: "Label for city title")
    static let pmAddressProvince = NSLocalizedString("pm.address.province", value: "Province", comment: "Label for province title")
    static let pmAddressPostalCode = NSLocalizedString("pm.address.postal-code", value: "Postal Code", comment: "Label for postal code title")
    static let pmPhoneNumber = NSLocalizedString("pm.phone-number", value: "Phone Number", comment: "Label for phone number title")
    static let pmEmailAddress = NSLocalizedString("pm.email-address", value: "Email Address", comment: "Label for email address title")

    static let pmNote = NSLocalizedString("pm.note", value: "Note", comment: "Label for note title")

}
