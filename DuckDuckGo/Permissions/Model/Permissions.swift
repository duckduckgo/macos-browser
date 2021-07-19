//
//  Permissions.swift
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

enum PermissionType: String, CaseIterable {
    case camera
    case microphone
    case geolocation
    case sound
    case display
}

extension Array where Element == PermissionType {

    @available(OSX 11.3, *)
    init?(devices: WKMediaCaptureType) {
        switch devices {
        case .camera:
            self = [.camera]
        case .microphone:
            self = [.microphone]
        case .cameraAndMicrophone:
            self = [.camera, .microphone]
        @unknown default:
            return nil
        }
    }

    init?(devices: _WKCaptureDevices) {
        var result = Array()
        if devices.contains(.camera) {
            result.append(.camera)
        }
        if devices.contains(.microphone) {
            result.append(.microphone)
        }
        if devices.contains(.display) {
            result.append(.display)
        }
        guard !result.isEmpty else { return nil }
        self = result
    }

}

enum PermissionAuthorizationState: String, CaseIterable {
    case ask
    case grant
    case deny
}

final class PermissionAuthorizationQuery {
    let domain: String
    let permissions: [PermissionType]

    private var completionHandler: ((PermissionAuthorizationQuery?, Bool) -> Void)?

    init(domain: String, permissions: [PermissionType], completionHandler: @escaping (PermissionAuthorizationQuery?, Bool) -> Void) {
        self.domain = domain
        self.permissions = permissions
        self.completionHandler = completionHandler
    }

    func handleDecision(grant: Bool) {
        completionHandler?(self, grant)
        completionHandler = nil
    }

    deinit {
        if let completionHandler = completionHandler {
            completionHandler(nil, false)
        }
    }

}

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

typealias Permissions = [PermissionType: PermissionState]

extension Dictionary where Key == PermissionType, Value == PermissionState {

    var microphone: PermissionState? {
        get {
            self[.microphone]
        }
        set {
            self[.microphone] = newValue
        }
    }
    
    var camera: PermissionState? {
        get {
            self[.camera]
        }
        set {
            self[.camera] = newValue
        }
    }

    var sound: PermissionState? {
        get {
            self[.sound]
        }
        set {
            self[.sound] = newValue
        }
    }

    var geolocation: PermissionState? {
        get {
            self[.geolocation]
        }
        set {
            self[.geolocation] = newValue
        }
    }

}
