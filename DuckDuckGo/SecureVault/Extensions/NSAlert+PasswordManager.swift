//
//  NSAlert+PasswordManager.swift
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

import AppKit

extension NSAlert {

    static func passwordManagerConfirmDeleteLogin() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.passwordManagerAlertRemovePasswordConfirmation
        alert.informativeText = UserText.thisActionCannotBeUndone
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.passwordManagerAlertDeleteButton)
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

    static func passwordManagerSaveChangesToLogin() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.passwordManagerAlertSaveChanges
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.save)
        alert.addButton(withTitle: UserText.discard)
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

    static func passwordManagerDuplicateLogin() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.passwordManagerAlertDuplicatePassword
        alert.informativeText = UserText.passwordManagerAlertDuplicatePasswordDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.ok)
        return alert
    }

    static func passwordManagerConfirmDeleteCard() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.passwordManagerAlertRemoveCardConfirmation
        alert.informativeText = UserText.thisActionCannotBeUndone
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.passwordManagerAlertDeleteButton)
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

    static func passwordManagerConfirmDeleteIdentity() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.passwordManagerAlertRemoveIdentityConfirmation
        alert.informativeText = UserText.thisActionCannotBeUndone
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.passwordManagerAlertDeleteButton)
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

    static func passwordManagerConfirmDeleteNote() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.passwordManagerAlertRemoveNoteConfirmation
        alert.informativeText = UserText.thisActionCannotBeUndone
        alert.alertStyle = .warning
        alert.addButton(withTitle: UserText.passwordManagerAlertDeleteButton)
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

    static func deleteAllPasswordsConfirmationAlert(count: Int, syncEnabled: Bool) -> NSAlert {
        let messageText = UserText.deleteAllPasswordsConfirmationMessageText(count: count)
        let informationText = UserText.deleteAllPasswordsConfirmationInformationText(syncEnabled: syncEnabled)
        return autofillActionConfirmationAlert(messageText: messageText,
                                        informationText: informationText,
                                        confirmButtonText: UserText.passwordManagerAlertDeleteButton)
    }

    private static func autofillActionConfirmationAlert(messageText: String,
                                                        informationText: String,
                                                        confirmButtonText: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informationText
        alert.alertStyle = .warning
        alert.addButton(withTitle: confirmButtonText)
        alert.addButton(withTitle: UserText.cancel)
        return alert
    }

    static func deleteAllPasswordsCompletionAlert(count: Int, syncEnabled: Bool) -> NSAlert {
        let messageText = UserText.deleteAllPasswordsCompletionMessageText(count: count)
        let informationText = UserText.deleteAllPasswordsCompletionInformationText(syncEnabled: syncEnabled)
        return autofillActionCompletionAlert(messageText: messageText,
                                      informationText: informationText)
    }

    private static func autofillActionCompletionAlert(messageText: String, informationText: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = informationText
        alert.addButton(withTitle: UserText.deleteAllPasswordsCompletionButtonText)
        return alert
    }
}
