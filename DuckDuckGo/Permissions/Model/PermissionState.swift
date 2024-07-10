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

    var isRequested: Bool {
        if case .requested = self { return true }
        return false
    }

    var isDenied: Bool {
        if case .denied = self { return true }
        return false
    }

}

extension Optional where Wrapped == PermissionState {

    var isActive: Bool {
        self == .active
    }

    var isPaused: Bool {
        self == .paused
    }

    static func combineCamera(_ camera: PermissionState?,
                              withMicrophone microphone: PermissionState?) -> (camera: PermissionState?, microphone: PermissionState?) {
        guard let camera = camera,
              let microphone = microphone
        else { return (camera, microphone) }

        switch (camera, microphone) {
        case (.active, .active),
             (.active, .paused),
             (.paused, .active),
             (.active, .inactive):
            return (camera: .active, microphone: nil)
        case (.inactive, .inactive):
            return (camera: .inactive, microphone: nil)
        case (.paused, .paused):
            return (camera: .paused, microphone: nil)
        case (.revoking, .revoking):
            return (camera: .revoking, microphone: nil)
        case (.denied, .denied):
            return (camera: .denied, microphone: nil)
        case (.reloading, .reloading):
            return (camera: .reloading, microphone: nil)
        case (.requested(let query), .requested):
            return (camera: .requested(query), microphone: nil)

        default:
            return (camera, microphone)
        }
    }

    mutating func authorizationQueried(_ query: PermissionAuthorizationQuery) {
        switch self {
        case .disabled, .requested:
            // stay in disabled state if the App is disabled to use the permission
            // stay in requested state for already queried permission
            return
        default:
            self = .requested(query)
        }
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

    mutating func popupOpened(nextQuery: PermissionAuthorizationQuery?) {
        if let nextQuery = nextQuery {
            self = .requested(nextQuery)
        } else if case .requested = self {
            self = .inactive
        }
    }

    mutating func externalSchemeOpened() {
        self = .inactive
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
        // Permission Activated
        case (.none, .active), (.paused, .active), (.inactive, .active), (.denied, .active):
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
