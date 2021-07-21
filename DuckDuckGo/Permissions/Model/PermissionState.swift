//
//  PermissionState.swift
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

enum PermissionState: Equatable {
    case disabled(systemWide: Bool)
    case requested(PermissionAuthorizationQuery)
    case active
    case revoking
    case denied
    case paused
    case inactive

    // swiftlint:disable cyclomatic_complexity
    static func == (lhs: PermissionState, rhs: PermissionState) -> Bool {
        switch lhs {
        case .disabled(systemWide: let systemWide): if case .disabled(systemWide) = rhs { return true }
        case .requested(let query1): if case .requested(let query2) = rhs, query1 === query2 { return true }
        case .active: if case .active = rhs { return true }
        case .revoking: if case .revoking = rhs { return true }
        case .denied: if case .denied = rhs { return true }
        case .paused: if case .paused = rhs { return true }
        case .inactive: if case .inactive = rhs { return true }
        }
        return false
    }
    // swiftlint:enable cyclomatic_complexity

}
