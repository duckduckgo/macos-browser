//
//  JSAlertViewModel.swift
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

final class JSAlertViewModel {
    private let query: JSAlertQuery

    init(query: JSAlertQuery) {
        self.query = query
    }

    var isCancelButtonHidden: Bool {
        switch query {
        case .alert:
            return true
        case .confirm, .textInput:
            return false
        }
    }

    var isTextFieldHidden: Bool {
        switch query {
        case .alert, .confirm:
            return true
        case .textInput:
            return false
        }
    }

    var isMessageScrollViewHidden: Bool {
        return query.parameters.prompt.count == 0
    }

    var okButtonText: String {
        UserText.ok
    }

    var cancelButtonText: String {
        UserText.cancel
    }

    var titleText: String {
        UserText.alertTitle(from: query.parameters.domain)
    }

    var messageText: String {
        query.parameters.prompt
    }

    var textFieldDefaultText: String {
        query.parameters.defaultInputText ?? ""
    }

    func confirm(text: String) {
        switch query {
        case .alert(let request):
            request.submit()
        case .confirm(let request):
            request.submit(true)
        case .textInput(let request):
            request.submit(text)
        }
    }

    func cancel() {
        query.cancel()
    }
}

fileprivate extension JSAlertQuery {
    var parameters: JSAlertParameters {
        switch self {
        case .alert(let request):
            return request.parameters
        case .confirm(let request):
            return request.parameters
        case .textInput(let request):
            return request.parameters
        }
    }
}
