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
        alert.messageText = "Are you sure you want to delete this Login?"
        alert.informativeText = "This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        return alert
    }

    static func passwordManagerSaveChangesToLogin() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Save the changes you made?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        return alert
    }

    static func passwordManagerDuplicateLogin() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Duplicate login"
        alert.informativeText = "You already have a login for this username and website."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        return alert
    }

    static func passwordManagerConfirmDeleteCard() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to delete this Payment Method from Autofill?"
        alert.informativeText = "This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        return alert
    }

    static func passwordManagerConfirmDeleteIdentity() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to delete this Info from Autofill?"
        alert.informativeText = "This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        return alert
    }

    static func passwordManagerConfirmDeleteNote() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to delete this note?"
        alert.informativeText = "This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        return alert
    }

}
