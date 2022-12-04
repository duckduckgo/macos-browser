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

import Foundation

struct SavePanelParameters {
    let suggestedFilename: String?
    let fileTypes: [UTType]
}

typealias OpenPanelQuery = OptionalCallbackQuery<WKOpenPanelParameters, [URL]?>
typealias SavePanelQuery = OptionalCallbackQuery<SavePanelParameters, (url: URL, fileType: UTType?)?>
typealias ConfirmQuery = OptionalCallbackQuery<String, Bool>
typealias TextInputQuery = OptionalCallbackQuery<(prompt: String, defaultText: String?), String?>
typealias AlertQuery = OptionalCallbackQuery<String, Void>
typealias BasicAuthQuery = OptionalCallbackQuery<URLProtectionSpace, (URLSession.AuthChallengeDisposition, URLCredential?)>
typealias PrintQuery = OptionalCallbackQuery<NSPrintOperation, Bool>
enum JSAlertQuery {
    case confirm(ConfirmQuery)
    case textInput(TextInputQuery)
    case alert(AlertQuery)
}

extension Tab {

    enum UserDialogType {
        case openPanel(OpenPanelQuery)
        case savePanel(SavePanelQuery)
        case jsDialog(JSAlertQuery)
        case basicAuthenticationChallenge(BasicAuthQuery)
        case print(PrintQuery)
    }

    enum UserDialogSender {
        case user
        case page(domain: String?)
    }

    struct UserDialog {
        let sender: UserDialogSender
        let dialog: UserDialogType

        var query: AnyOptionalCallbackQuery {
            switch dialog {
            case .openPanel(let query): return query
            case .savePanel(let query): return query
            case .jsDialog(.confirm(let query)): return query
            case .jsDialog(.textInput(let query)): return query
            case .jsDialog(.alert(let query)): return query
            case .basicAuthenticationChallenge(let query): return query
            case .print(let query): return query
            }
        }
    }

}
