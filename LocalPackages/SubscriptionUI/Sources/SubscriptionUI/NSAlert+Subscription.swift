//
//  NSAlert+Subscription.swift
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
import AppKit

public extension NSAlert {

    static func somethingWentWrongAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.somethingWentWrongAlertTitle
        alert.informativeText = UserText.somethingWentWrongAlertDescription
        alert.addButton(withTitle: UserText.okButtonTitle)
        return alert
    }

    static func subscriptionNotFoundAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.subscriptionNotFoundAlertTitle
        alert.informativeText = UserText.subscriptionNotFoundAlertDescription
        alert.addButton(withTitle: UserText.viewPlansButtonTitle)
        alert.addButton(withTitle: UserText.cancelButtonTitle)
        return alert
    }

    static func subscriptionInactiveAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.subscriptionInactiveAlertTitle
        alert.informativeText = UserText.subscriptionInactiveAlertDescription
        alert.addButton(withTitle: UserText.viewPlansButtonTitle)
        alert.addButton(withTitle: UserText.cancelButtonTitle)
        return alert
    }

    static func subscriptionFoundAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.subscriptionFoundAlertTitle
        alert.informativeText = UserText.subscriptionFoundAlertDescription
        alert.addButton(withTitle: UserText.restoreButtonTitle)
        alert.addButton(withTitle: UserText.cancelButtonTitle)
        return alert
    }

    static func appleIDSyncFailedAlert(text: String) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = UserText.subscriptionAppleIDSyncFailedAlertTitle
        alert.informativeText = text
        alert.addButton(withTitle: UserText.continueButtonTitle)
        alert.addButton(withTitle: UserText.cancelButtonTitle)
        return alert
    }

}

public extension NSWindow {

    func show(_ alert: NSAlert, firstButtonAction: (() -> Void)? = nil) {
        alert.beginSheetModal(for: self, completionHandler: { response in
            if case .alertFirstButtonReturn = response {
                firstButtonAction?()
            }
        })
    }
}
