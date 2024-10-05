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
import Navigation
import WebKit
import UniformTypeIdentifiers

struct SavePanelParameters {
    let suggestedFilename: String?
    let fileTypes: [UTType]
}

struct JSAlertParameters {
    let domain: String
    let prompt: String
    let defaultInputText: String?
}

typealias OpenPanelDialogRequest = UserDialogRequest<WKOpenPanelParameters, [URL]?>
typealias SavePanelDialogRequest = UserDialogRequest<SavePanelParameters, (url: URL, fileType: UTType?)?>
typealias ConfirmDialogRequest = UserDialogRequest<JSAlertParameters, Bool>
typealias TextInputDialogRequest = UserDialogRequest<JSAlertParameters, String?>
typealias AlertDialogRequest = UserDialogRequest<JSAlertParameters, Void>
typealias BasicAuthDialogRequest = UserDialogRequest<URLProtectionSpace, AuthChallengeDisposition?>
typealias PrintDialogRequest = UserDialogRequest<NSPrintOperation, Bool>

enum JSAlertQuery: Equatable {
    case confirm(ConfirmDialogRequest)
    case textInput(TextInputDialogRequest)
    case alert(AlertDialogRequest)

    func cancel() {
        switch self {
        case .alert(let request):
            return request.submit()
        case .confirm(let request):
            return request.submit(false)
        case .textInput(let request):
            return request.submit(nil)
        }
    }

    static func == (lhs: JSAlertQuery, rhs: JSAlertQuery) -> Bool {
        switch lhs {
        case .confirm(let r1): if case .confirm(let r2) = rhs { r1 === r2 } else { false }
        case .textInput(let r1): if case .textInput(let r2) = rhs { r1 === r2 } else { false }
        case .alert(let r1): if case .alert(let r2) = rhs { r1 === r2 } else { false }
        }
    }
}

extension Tab {

    enum UserDialogType: Equatable {
        case openPanel(OpenPanelDialogRequest)
        case savePanel(SavePanelDialogRequest)
        case jsDialog(JSAlertQuery)
        case basicAuthenticationChallenge(BasicAuthDialogRequest)
        case print(PrintDialogRequest)

        static func == (lhs: Tab.UserDialogType, rhs: Tab.UserDialogType) -> Bool {
            switch lhs {
            case .openPanel(let r1): if case .openPanel(let r2) = rhs { r1 === r2 } else { false }
            case .savePanel(let r1): if case .savePanel(let r2) = rhs { r1 === r2 } else { false }
            case .jsDialog(let r1): if case .jsDialog(let r2) = rhs { r1 == r2 } else { false }
            case .basicAuthenticationChallenge(let r1): if case .basicAuthenticationChallenge(let r2) = rhs { r1 === r2 } else { false }
            case .print(let r1): if case .print(let r2) = rhs { r1 === r2 } else { false }
            }
        }

    }

    enum UserDialogSender: Equatable {
        case user
        case page(domain: String)
    }

    struct UserDialog: Equatable {
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

        static func == (lhs: Tab.UserDialog, rhs: Tab.UserDialog) -> Bool {
            lhs.sender == rhs.sender && lhs.dialog == rhs.dialog
        }

    }

}
