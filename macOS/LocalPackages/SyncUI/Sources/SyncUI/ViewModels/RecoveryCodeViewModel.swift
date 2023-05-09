//
//  RecoveryCodeViewModel.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import Combine
import AppKit

final public class RecoveryCodeViewModel: ObservableObject {
    @Published public var shouldDisableSubmitButton: Bool = true
    @Published public private(set) var recoveryCode: String = "" {
        didSet {
            shouldDisableSubmitButton = recoveryCode.isEmpty
        }
    }

    func setCode(_ code: String) {
        if CharacterSet.base64.isSuperset(of: CharacterSet(charactersIn: code)) {
            recoveryCode = code
        }
    }

    func paste() {
        let code = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "") ?? ""
        setCode(code)
    }

    public init() {}
}

extension CharacterSet {
    static var base64: CharacterSet {
        return CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
    }
}
