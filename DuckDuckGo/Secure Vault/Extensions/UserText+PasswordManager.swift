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

// swiftlint:disable line_length
extension UserText {
    
    static let pmEmptyStateDefaultTitle = NSLocalizedString("pm.empty.default.title", value: "No Logins or Payment Methods saved yet", comment: "Label for default empty state title")
    static let pmEmptyStateDefaultDescription = NSLocalizedString("pm.empty.default.description",
                                                                  value: "If your logins are saved in another browser, you can import them into DuckDuckGo.",
                                                                  comment: "Label for default empty state description")
    
    static let pmEmptyStateLoginsTitle = NSLocalizedString("pm.empty.logins.title", value: "No Logins", comment: "Label for logins empty state title")
    static let pmEmptyStateIdentitiesTitle = NSLocalizedString("pm.empty.identities.title", value: "No Identities", comment: "Label for identities empty state title")
    static let pmEmptyStateCardsTitle = NSLocalizedString("pm.empty.cards.title", value: "No Cards", comment: "Label for cards empty state title")
    static let pmEmptyStateNotesTitle = NSLocalizedString("pm.empty.notes.title", value: "No Notes", comment: "Label for notes empty state title")

    static let pmNewCard = NSLocalizedString("pm.new.card", value: "Credit Card", comment: "Label for new card title")
    static let pmNewLogin = NSLocalizedString("pm.new.login", value: "Login", comment: "Label for new login title")
    static let pmNewIdentity = NSLocalizedString("pm.new.identity", value: "Identity", comment: "Label for new identity title")
    static let pmNewNote = NSLocalizedString("pm.new.note", value: "Note", comment: "Label for new note title")

    static let pmDelete = NSLocalizedString("pm.delete", value: "Delete", comment: "Delete button")
    static let pmCancel = NSLocalizedString("pm.cancel", value: "Cancel", comment: "Cancel button")
    static let pmSave = NSLocalizedString("pm.save", value: "Save", comment: "Save button")
    static let pmEdit = NSLocalizedString("pm.edit", value: "Edit", comment: "Edit button")
    static let pmUsername = NSLocalizedString("pm.username", value: "Username", comment: "Label for username edit field")
    static let pmPassword = NSLocalizedString("pm.password", value: "Password", comment: "Label for password edit field")
    static let pmWebsite = NSLocalizedString("pm.website", value: "Website URL", comment: "Label for website edit field")
    static let pmLoginAdded = NSLocalizedString("pm.added", value: "Added", comment: "Label for login added data")
    static let pmLoginLastUpdated = NSLocalizedString("pm.last.updated", value: "Last Updated", comment: "Label for last updated edit field")

    static let pmCardNumber = NSLocalizedString("pm.card.number", value: "Card Number", comment: "Label for card number title")
    static let pmCardholderName = NSLocalizedString("pm.card.cardholder-name", value: "Cardholder Name", comment: "Label for cardholder name title")
    static let pmCardVerificationValue = NSLocalizedString("pm.card.cvv", value: "CVV", comment: "Label for CVV title")
    static let pmCardExpiration = NSLocalizedString("pm.card.expiration-date", value: "Expiration Date", comment: "Label for expiration date title")

    static let pmIdentification = NSLocalizedString("pm.identification", value: "Identification", comment: "Label for identification title")
    static let pmFirstName = NSLocalizedString("pm.name.first", value: "First Name", comment: "Label for first name title")
    static let pmMiddleName = NSLocalizedString("pm.name.middle", value: "Middle Name", comment: "Label for middle name title")
    static let pmLastName = NSLocalizedString("pm.name.last", value: "Last Name", comment: "Label for last name title")
    static let pmDay = NSLocalizedString("pm.day", value: "Day", comment: "Label for Day title")
    static let pmMonth = NSLocalizedString("pm.month", value: "Month", comment: "Label for Month title")
    static let pmYear = NSLocalizedString("pm.year", value: "Year", comment: "Label for Year title")

    static let pmAddress1 = NSLocalizedString("pm.address.address1", value: "Address 1", comment: "Label for address 1 title")
    static let pmAddress2 = NSLocalizedString("pm.address.address2", value: "Address 2", comment: "Label for address 2 title")
    static let pmAddressCity = NSLocalizedString("pm.address.city", value: "City", comment: "Label for city title")
    static let pmAddressProvince = NSLocalizedString("pm.address.state-province", value: "State/Province", comment: "Label for state/province title")
    static let pmAddressPostalCode = NSLocalizedString("pm.address.postal-code", value: "Postal Code", comment: "Label for postal code title")
    static let pmPhoneNumber = NSLocalizedString("pm.phone-number", value: "Phone Number", comment: "Label for phone number title")
    static let pmEmailAddress = NSLocalizedString("pm.email-address", value: "Email Address", comment: "Label for email address title")

    static let pmNote = NSLocalizedString("pm.note", value: "Note", comment: "Label for note title")
    static let pmEmptyNote = NSLocalizedString("pm.note.empty", value: "Empty note", comment: "Label for empty note title")
    
    static let pmDefaultIdentityAutofillTitle = NSLocalizedString("pm.identity.autofill.title.default", value: "Address", comment: "Default title for Addresses/Identities")
    
    static let pmSortStringAscending = NSLocalizedString("pm.sort.string.ascending", value: "Alphabetically", comment: "Label for Ascending string sort order")
    static let pmSortStringDescending = NSLocalizedString("pm.sort.string.descending", value: "Reverse Alphabetically", comment: "Label for Descending string sort order")
    static let pmSortDateAscending = NSLocalizedString("pm.sort.date.ascending", value: "Newest First", comment: "Label for Ascending date sort order")
    static let pmSortDateDescending = NSLocalizedString("pm.sort.date.descending", value: "Oldest First", comment: "Label for Descending date sort order")
    
    static let pmSortParameterTitle = NSLocalizedString("pm.sort.parameter.title", value: "Title", comment: "Label for Title sort parameter")
    static let pmSortParameterDateCreated = NSLocalizedString("pm.sort.parameter.date-created", value: "Date Created", comment: "Label for Date Created sort parameter")
    static let pmSortParameterDateModified = NSLocalizedString("pm.sort.parameter.date-modified", value: "Date Modified", comment: "Label for Date Modified sort parameter")
    
    static func pmLockScreenDuration(duration: String) -> String {
        let localized = NSLocalizedString("pm.lock-screen.duration",
                                          value: "Your Autofill info will remain unlocked until your computer is idle for %@.",
                                          comment: "")
        return String(format: localized, duration)
    }
    
    static let pmLockScreenPreferencesLabel = NSLocalizedString("pm.lock-screen.preferences.label", value: "Change in", comment: "Label used for a button that opens preferences")
    static let pmLockScreenPreferencesLink = NSLocalizedString("pm.lock-screen.preferences.link", value: "Preferences", comment: "Label used for a button that opens preferences")
    
    static let pmAutoLockPromptUnlockLogins = NSLocalizedString("pm.lock-screen.prompt.unlock-logins", value: "unlock access to your Autofill info", comment: "Label presented when unlocking Autofill")
    static let pmAutoLockPromptChangeLoginsSettings = NSLocalizedString("pm.lock-screen.prompt.change-settings", value: "change your Autofill info access settings", comment: "Label presented when changing Auto-Lock settings")
    static let pmAutoLockPromptAutofill = NSLocalizedString("pm.lock-screen.prompt.autofill", value: "autofill credit card information", comment: "Label presented when autofilling credit card information")
    
    static let autoLockThreshold1Minute = NSLocalizedString("pm.lock-screen.threshold.1-minute", value: "1 minute", comment: "Label used when selecting the Auto-Lock threshold")
    static let autoLockThreshold5Minutes = NSLocalizedString("pm.lock-screen.threshold.5-minutes", value: "5 minutes", comment: "Label used when selecting the Auto-Lock threshold")
    static let autoLockThreshold15Minutes = NSLocalizedString("pm.lock-screen.threshold.15-minutes", value: "15 minutes", comment: "Label used when selecting the Auto-Lock threshold")
    static let autoLockThreshold30Minutes = NSLocalizedString("pm.lock-screen.threshold.30-minutes", value: "30 minutes", comment: "Label used when selecting the Auto-Lock threshold")
    static let autoLockThreshold1Hour = NSLocalizedString("pm.lock-screen.threshold.1-hour", value: "1 hour", comment: "Label used when selecting the Auto-Lock threshold")
    
}
