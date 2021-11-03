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
import WebKit

enum PermissionState: Equatable {
    case disabled(systemWide: Bool)
    case requested(PermissionAuthorizationQuery)
    case active
    case revoking
    case reloading
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
        case .reloading: if case .reloading = rhs { return true }
        case .denied: if case .denied = rhs { return true }
        case .paused: if case .paused = rhs { return true }
        case .inactive: if case .inactive = rhs { return true }
        }
        return false
    }
    // swiftlint:enable cyclomatic_complexity

}

extension Optional where Wrapped == PermissionState {

    var isActive: Bool {
        self == .active
    }

    var isPaused: Bool {
        self == .paused
    }

    func combined(with other: PermissionState?) -> PermissionState? {
        guard let lhs = self else { return nil }
        guard let rhs = other else { return lhs }

        switch (lhs, rhs) {
        case (.active, _), (_, .active):
            return .active
        case (.paused, _), (_, .paused):
            return .paused
        case (.inactive, _), (_, .inactive):
            return .inactive
        case (.requested(let query), _), (_, .requested(let query)):
            return .requested(query)

        case (.revoking, _), (_, .revoking):
            return .revoking
        case (.reloading, _), (_, .reloading):
            return .reloading
        case (.denied, _), (_, .denied):
            return .denied
        case (.disabled(let systemWide), _), (_, .disabled(let systemWide)):
            return .disabled(systemWide: systemWide)
        }
    }

    mutating func authorizationQueried(_ query: PermissionAuthorizationQuery) {
        if case .some(.disabled) = self {
            // stay in disabled state if the App is disabled to use the permission
            return
        }
        self = .requested(query)
    }

    mutating func systemAuthorizationDenied(systemWide: Bool) {
        self = .disabled(systemWide: systemWide)
    }

    mutating func systemAuthorizationGranted(pendingQuery: PermissionAuthorizationQuery) {
        self = .requested(pendingQuery)
    }

    mutating func granted() {
        guard case .some(.requested) = self else { return }
        // becomes `active` after handling activation of a permission by the WebView
        self = .inactive
    }

    mutating func denied() {
        self = .denied
    }

    mutating func update(with captureState: WKWebView.CaptureState) {
        switch (self, captureState) {
        // same state
        case (.active, .active), (.paused, .muted), (.none, .none), (.inactive, .none),
             // (Disabled -> not used) stays Disabled
             (.disabled, .none), (.denied, .none):
            return

        // Permission Granted
        case (.requested, .active), (.disabled, .active):
            self = .active

        case (.revoking, .active), (.revoking, .muted), (.reloading, .active), (.reloading, .muted):
            // Probably Active Camera + Microphone -> Active Camera state change, stay in Revoking state
            break
        case (.denied, .active):
            assertionFailure("Unexpected change of system disabled Permission")
            fallthrough
        // Permission Activated
        case (.none, .active), (.paused, .active), (.inactive, .active):
            self = .active

        case (.disabled, .muted), (.denied, .muted), (.requested, .muted):
            assertionFailure("Unexpected change of system disabled Permission")
            fallthrough
        // Muted
        case (.active, .muted), (.none, .muted), (.inactive, .muted):
            self = .paused

        // Permission deactivated
        case (.active, .none), (.paused, .none), (.requested, .none):
            self = .inactive

        // Permission revoked
        case (.revoking, .none):
            self = .denied

        // Permission revoked on page reload
        case (.reloading, .none):
            self = .none
        }
    }

    mutating func revoke() {
        guard case .some = self else { return }
        self = .revoking
    }

    mutating func willReload() {
        switch self {
        case .active, .paused:
            self = .reloading
        case .none, .disabled, .requested, .revoking, .reloading, .denied, .inactive:
            self = .none
        }
    }

}
