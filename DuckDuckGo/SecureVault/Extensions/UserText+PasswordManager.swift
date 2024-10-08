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

    static let pmSaveCredentialsEditableTitle = NSLocalizedString("pm.save-credentials.editable.title", value: "Save password in DuckDuckGo?", comment: "Title for the editable Save Credentials popover")
    static let pmSaveCredentialsNonEditableTitle = NSLocalizedString("pm.save-credentials.non-editable.title", value: "New password saved", comment: "Title for the non-editable Save Credentials popover")
    static let pmSaveCredentialsSecurityInfo = NSLocalizedString("pm.save-credentials.security.info", value: "Passwords are encrypted. Nobody but you can see them, not even us. [Learn More](https://duckduckgo.com/duckduckgo-help-pages/sync-and-backup/password-manager-security/)", comment: "Info message for the save credentials dialog")
    static let pmSaveCredentialsSecurityInfoAutolockOff = NSLocalizedString("pm.save-credentials.security.info.autolock.off", value: "Passwords are encrypted. We recommend setting up Auto-lock to keep your passwords even more secure. [Go to Settings](duck://settings/autofill)", comment: "Info message for the save credentials dialog when the autolock feature is off")
    static let pmUpdateCredentialsTitle = NSLocalizedString("pm.update-credentials.title", value: "Update password?", comment: "Title for the Update Credentials popover")

    static let pmEmptyStateDefaultTitle = NSLocalizedString("pm.empty.default.title", value: "No passwords or credit cards saved yet", comment: "Label for default empty state title")
    static let pmEmptyStateDefaultDescription = NSLocalizedString("pm.empty.default.description.extended.v2",
                                                                  value: "Passwords are encrypted. Nobody but you can see them, not even us.",
                                                                  comment: "Label for default empty state description")
    static let pmEmptyStateDefaultDescriptionAutolockOff = NSLocalizedString("pm.empty.default.description.extended.v2.autolock.off",
                                                                             value: "Passwords are encrypted.",
                                                                             comment: "Label for default empty state description when the autolock feature is off")
    static let pmEmptyStateLearnMoreLink = NSLocalizedString("pm.empty.learn.more.link", value: "Learn more", comment: "Text for link to learn more about DuckDuckGo password manager")
    static let pmEmptyStateDefaultButtonTitle = NSLocalizedString("pm.empty.default.button.title", value: "Import Passwords", comment: "Import passwords button title for default empty state")

    static let pmEmptyStateLoginsTitle = NSLocalizedString("pm.empty.logins.title", value: "No passwords saved yet", comment: "Label for logins empty state title")
    static let pmEmptyStateIdentitiesTitle = NSLocalizedString("pm.empty.identities.title", value: "No Identities", comment: "Label for identities empty state title")
    static let pmEmptyStateCardsTitle = NSLocalizedString("pm.empty.cards.title", value: "No Cards", comment: "Label for cards empty state title")
    static let pmEmptyStateNotesTitle = NSLocalizedString("pm.empty.notes.title", value: "No Notes", comment: "Label for notes empty state title")

    static let pmAddItem = NSLocalizedString("pm.add.new", value: "Add New", comment: "Add New item button")
    static let pmAddCard = NSLocalizedString("pm.add.card", value: "Add Credit Card", comment: "Add New Credit Card button")
    static let pmAddLogin = NSLocalizedString("pm.add.login", value: "Add Password", comment: "Add New Login button")
    static let pmAddIdentity = NSLocalizedString("pm.add.identity", value: "Add Identity", comment: "Add New Identity button")
    static let pmNewCard = NSLocalizedString("pm.new.card", value: "Credit Card", comment: "Label for new card title")
    static let pmNewLogin = NSLocalizedString("pm.new.login", value: "Password", comment: "Label for new login title")
    static let pmNewIdentity = NSLocalizedString("pm.new.identity", value: "Identity", comment: "Label for new identity title")
    static let pmNewNote = NSLocalizedString("pm.new.note", value: "Note", comment: "Label for new note title")

    static let pmDelete = NSLocalizedString("pm.delete", value: "Delete", comment: "Delete button")
    static let pmCancel = NSLocalizedString("pm.cancel", value: "Cancel", comment: "Cancel button")
    static let pmSave = NSLocalizedString("pm.save", value: "Save", comment: "Save button")
    static let pmEdit = NSLocalizedString("pm.edit", value: "Edit", comment: "Edit button")
    static let pmUsername = NSLocalizedString("pm.username", value: "Username", comment: "Label for username edit field")
    static let pmPassword = NSLocalizedString("pm.password", value: "Password", comment: "Label for password edit field")
    static let pmWebsite = NSLocalizedString("pm.website", value: "Website URL", comment: "Label for website edit field")
    static let pmNotes = NSLocalizedString("pm.notes", value: "Notes", comment: "Label for notes edit field")
    static let pmLoginAdded = NSLocalizedString("pm.added", value: "Added", comment: "Label for login added data")
    static let pmLoginLastUpdated = NSLocalizedString("pm.last.updated", value: "Last Updated", comment: "Label for last updated edit field")

    static let pmDeactivateAddress = NSLocalizedString("pm.deactivate.private.email", value: "Deactivate Duck Address", comment: "Deactivate private email address button")
    static let pmActivateAddress = NSLocalizedString("pm.activate.private.email", value: "Reactivate Duck Address", comment: "Activate private email address button")
    static let pmDeactivate = NSLocalizedString("pm.deactivate", value: "Deactivate", comment: "Deactivate button")
    static let pmActivate = NSLocalizedString("pm.activate", value: "Reactivate", comment: "Activate button")
    static let pmEmailMessageActive = NSLocalizedString("pm.private.email.mesage.active", value: "Duck Address Active", comment: "Mesasage displayed when a private email address is active")
    static let pmEmailMessageInactive = NSLocalizedString("pm.private.email.mesage.inactive", value: "Duck Address Deactivated", comment: "Mesasage displayed when a private email address is inactive")
    static let pmEmailMessageError = NSLocalizedString("pm.private.email.mesage.error", value: "Management of this address is temporarily unavailable.", comment: "Mesasage displayed when a user tries to manage a private email address but the service is not available, returns an error or network is down")
    static let pmEmailActivateConfirmTitle = NSLocalizedString("pm.private.email.mesage.activate.confirm.title", value: "Reactivate Private Duck Address?", comment: "Title for the confirmation message  displayed when a user tries activate a Private Email Address")
    static let pmEmailActivateConfirmContent = NSLocalizedString("pm.private.email.mesage.activate.confirm.content", value: "Emails sent to %@ will again be forwarded to your inbox.", comment: "Text for the confirmation message displayed when a user tries activate a Private Email Address")
    static let pmEmailDeactivateConfirmTitle = NSLocalizedString("pm.private.email.mesage.deactivate.confirm.title", value: "Deactivate Private Duck Address?", comment: "Title for the confirmation message displayed when a user tries deactivate a Private Email Address")
    static let pmEmailDeactivateConfirmContent = NSLocalizedString("pm.private.email.mesage.deactivate.confirm.content", value: "Emails sent to %@ will no longer be forwarded to your inbox.", comment: "Text for the confirmation message displayed when a user tries deactivate a Private Email Address")
    static let pmRemovedDuckAddressTitle = NSLocalizedString("pm.removed.duck.address.title", value: "Private Duck Address username was removed", comment: "Title for the alert dialog telling the user an updated username is no longer a private email address")
    static let pmRemovedDuckAddressContent = NSLocalizedString("pm.removed.duck.address.content", value: "You can still manage this Duck Address from emails received from it in your personal inbox.", comment: "Content for the alert dialog telling the user an updated username is no longer a private email address")
    static let pmRemovedDuckAddressButton = NSLocalizedString("pm.removed.duck.address.button", value: "Got it", comment: "Button text for the alert dialog telling the user an updated username is no longer a private email address")
    static let pmSignInToManageEmail = NSLocalizedString("pm.signin.to.manage", value: "%@ to manage your Duck Addresses on this device.", comment: "Message displayed to the user when they are logged out of Email protection.")
    static let pmEnableEmailProtection = NSLocalizedString("pm.enable.email.protection", value: "Enable Email Protection", comment: "Text link to email protection website")
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
                                          value: "Your autofill info will remain unlocked until your computer is idle for %@.",
                                          comment: "Message about the duration for which autofill information remains unlocked on the lock screen.")
        return String(format: localized, duration)
    }

    static let pmLockScreenPreferencesLabel = NSLocalizedString("pm.lock-screen.preferences.label", value: "Change in", comment: "Label used for a button that opens preferences")
    static let pmLockScreenPreferencesLink = NSLocalizedString("pm.lock-screen.preferences.link", value: "Settings", comment: "Label used for a button that opens preferences")

    static let pmAutoLockPromptUnlockLogins = NSLocalizedString("pm.lock-screen.prompt.unlock-logins", value: "unlock your passwords and autofill info for you", comment: "Label presented when unlocking Autofill")
    static let pmAutoLockPromptExportLogins = NSLocalizedString("pm.lock-screen.prompt.export-logins", value: "export your usernames and passwords", comment: "Label presented when exporting logins")
    static let pmAutoLockPromptChangeLoginsSettings = NSLocalizedString("pm.lock-screen.prompt.change-settings", value: "change your autofill info access settings", comment: "Label presented when changing Auto-Lock settings")
    static let pmAutoLockPromptAutofill = NSLocalizedString("pm.lock-screen.prompt.autofill", value: "unlock access to your autofill info", comment: "Label presented when autofilling credit card information")

    static let autoLockThreshold1Minute = NSLocalizedString("pm.lock-screen.threshold.1-minute", value: "1 minute", comment: "Label used when selecting the Auto-Lock threshold")
    static let autoLockThreshold5Minutes = NSLocalizedString("pm.lock-screen.threshold.5-minutes", value: "5 minutes", comment: "Label used when selecting the Auto-Lock threshold")
    static let autoLockThreshold15Minutes = NSLocalizedString("pm.lock-screen.threshold.15-minutes", value: "15 minutes", comment: "Label used when selecting the Auto-Lock threshold")
    static let autoLockThreshold30Minutes = NSLocalizedString("pm.lock-screen.threshold.30-minutes", value: "30 minutes", comment: "Label used when selecting the Auto-Lock threshold")
    static let autoLockThreshold1Hour = NSLocalizedString("pm.lock-screen.threshold.1-hour", value: "1 hour", comment: "Label used when selecting the Auto-Lock threshold")
    static let autoLockThreshold12Hours = NSLocalizedString("pm.lock-screen.threshold.12-hours", value: "12 hours", comment: "Label used when selecting the Auto-Lock threshold")

    // MARK: Autofill Item Deletion (Autofill -> More Menu, Settings -> Autofill)
    static let deleteAllPasswords = NSLocalizedString("autofill.items.delete-all-passwords", value: "Delete All Passwords…", comment: "Opens Delete All Passwords dialog")

    // Confirmation Message Text
    static func deleteAllPasswordsConfirmationMessageText(count: Int) -> String {
        let localized = NSLocalizedString("autofill.items.delete-all-passwords-confirmation-message-text", value: "Are you sure you want to delete all passwords (%d)?", comment: "Message displayed on dialog asking user to confirm deletion of all passwords")
        return String(format: localized, count)
    }

    // Confirmation Information Text
    static func deleteAllPasswordsConfirmationInformationText(syncEnabled: Bool) -> String {
        if syncEnabled {
            return NSLocalizedString("autofill.items.delete-all-passwords-synced-confirmation-information-text", value: "Your passwords will be deleted from all synced devices. Make sure you still have a way to access your accounts.", comment: "Information message displayed when deleting all passwords on a synced device")
        } else {
            return NSLocalizedString("autofill.items.delete-all-passwords-device-confirmation-information-text", value: "Your passwords will be deleted from this device. Make sure you still have a way to access your accounts.", comment: "Information message displayed when deleting all passwords on a device")
        }
    }

    // Completion Message Text
    static func deleteAllPasswordsCompletionMessageText(count: Int) -> String {
        let localized = NSLocalizedString("autofill.items.delete-all-passwords-completion-message-text", value: "All passwords deleted (%d)", comment: "Message displayed on completion of multiple password deletion")
        return String(format: localized, count)
    }

    // Completion Information Text
    static func deleteAllPasswordsCompletionInformationText(syncEnabled: Bool) -> String {
        if syncEnabled {
            return NSLocalizedString("autofill.items.delete-all-passwords-synced-completion-information-text",
                                     value: "Your passwords have been deleted from all synced devices.",
                                     comment: "Information message displayed on completion of multiple password deletion when devices are synced")
        } else {
            return ""
        }
    }

    // Completion Close Button
    static let deleteAllPasswordsCompletionButtonText = NSLocalizedString("autofill.items.delete-all-passwords-completion-button-texy", value: "Close", comment: "Button text on dialog confirming deletion was completed")

    // System Alert Permission Text
    static let deleteAllPasswordsPermissionText = NSLocalizedString("autofill.items.delete-all-passwords-permisson-text", value: "delete all passwords", comment: "Message displayed in system authentication dialog")

}
