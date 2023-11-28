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
        alert.messageText = "Something Went Wrong"
        alert.informativeText = "The App Store was not able to process your purchase. Please try again later."
        alert.addButton(withTitle: "OK")
        return alert
    }

    static func subscriptionNotFoundAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Subscription Not Found"
        alert.informativeText = "We couldn’t find a subscription associated with this Apple ID."
        alert.addButton(withTitle: "View Plans")
        alert.addButton(withTitle: "Cancel")
        return alert
    }

    static func subscriptionInactiveAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Subscription Not Found"
        alert.informativeText = "The subscription associated with this Apple ID is no longer active."
        alert.addButton(withTitle: "View Plans")
        alert.addButton(withTitle: "Cancel")
        return alert
    }


    static func subscriptionFoundAlert() -> NSAlert {
        let alert = NSAlert()
        alert.messageText = "Subscription Found"
        alert.informativeText = "We found a subscription associated with this Apple ID."
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")
        return alert
    }
}
