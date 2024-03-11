//
//  AutofillActionPresenter.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

/// Conforming types handles presentation of `NSAlert`s associated with an `AutofillActionExecutor`
protocol AutofillActionPresenter {
    func show(actionExecutor: AutofillActionExecutor, completion: @escaping () -> Void)
}

/// Handles presentation of an alert associated with an `AutofillActionExecutor`
struct DefaultAutofillActionPresenter: AutofillActionPresenter {

    @MainActor
    func show(actionExecutor: AutofillActionExecutor, completion: @escaping  () -> Void) {
        guard let window else { return }

        let confirmationAlert = actionExecutor.confirmationAlert
        let completionAlert = actionExecutor.completionAlert

        confirmationAlert.beginSheetModal(for: window) { response in
            switch response {
            case .alertFirstButtonReturn:
                actionExecutor.execute {
                    completion()
                    show(completionAlert)
                }
            default:
                break
            }
        }
    }
}

private extension DefaultAutofillActionPresenter {

    @MainActor
    func show(_ alert: NSAlert) {
        guard let window else { return }
        alert.beginSheetModal(for: window)
    }

    @MainActor
    var window: NSWindow? {
        WindowControllersManager.shared.lastKeyMainWindowController?.window
    }
}
