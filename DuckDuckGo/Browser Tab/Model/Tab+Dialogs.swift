//
//  Tab+Dialogs.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import BrowserServicesKit
import Foundation
import WebKit

struct SavePanelParameters {
    let suggestedFilename: String?
    let fileTypes: [UTType]
}

typealias OpenPanelDialogRequest = UserDialogRequest<WKOpenPanelParameters, [URL]?>
typealias SavePanelDialogRequest = UserDialogRequest<SavePanelParameters, (url: URL, fileType: UTType?)?>
typealias ConfirmDialogRequest = UserDialogRequest<String, Bool>
typealias TextInputDialogRequest = UserDialogRequest<(prompt: String, defaultText: String?), String?>
typealias AlertDialogRequest = UserDialogRequest<String, Void>
typealias BasicAuthDialogRequest = UserDialogRequest<URLProtectionSpace, AuthChallengeDisposition?>
typealias PrintDialogRequest = UserDialogRequest<NSPrintOperation, Bool>

enum JSAlertQuery {
    case confirm(ConfirmDialogRequest)
    case textInput(TextInputDialogRequest)
    case alert(AlertDialogRequest)
}

extension Tab {

    enum UserDialogType {
        case openPanel(OpenPanelDialogRequest)
        case savePanel(SavePanelDialogRequest)
        case jsDialog(JSAlertQuery)
        case basicAuthenticationChallenge(BasicAuthDialogRequest)
        case print(PrintDialogRequest)
    }

    enum UserDialogSender {
        case user
        case page(domain: String?)
    }

    struct UserDialog {
        let sender: UserDialogSender
        let dialog: UserDialogType

        var request: AnyUserDialogRequest {
            switch dialog {
            case .openPanel(let request): return request
            case .savePanel(let request): return request
            case .jsDialog(.confirm(let request)): return request
            case .jsDialog(.textInput(let request)): return request
            case .jsDialog(.alert(let request)): return request
            case .basicAuthenticationChallenge(let request): return request
            case .print(let request): return request
            }
        }
    }

}
