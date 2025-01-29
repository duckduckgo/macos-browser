//
//  Action.swift
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

enum ActionType: String, Codable, Sendable {
    case extract
    case navigate
    case fillForm
    case click
    case expectation
    case emailConfirmation
    case getCaptchaInfo
    case solveCaptcha
}

enum DataSource: String, Codable {
    case userProfile
    case extractedProfile
}

protocol Action: Codable, Sendable {
    var id: String { get }
    var actionType: ActionType { get }
    var needsEmail: Bool { get }
    var dataSource: DataSource { get }
}

extension Action {
    var needsEmail: Bool { false }
    var dataSource: DataSource { .userProfile }
}
