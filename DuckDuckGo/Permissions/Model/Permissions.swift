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
    case cameraAndMicrophone
    case geolocation
    case sound

    @available(OSX 11.3, *)
    init?(devices: WKMediaCaptureType) {
        switch devices {
        case .camera:
            self = .camera
        case .microphone:
            self = .microphone
        case .cameraAndMicrophone:
            self = .cameraAndMicrophone
        @unknown default:
            return nil
        }
    }

    init?(devices: _WKCaptureDevices) {
        if devices.contains(.camera) {
            if devices.contains(.microphone) {
                self = .cameraAndMicrophone
            } else {
                self = .camera
            }
        } else if devices.contains(.microphone) {
            self = .microphone
        } else {
            return nil
        }
    }
}

enum PermissionAuthorizationState: String, CaseIterable {
    case ask
    case grant
    case deny
}

final class PermissionAuthorizationQuery {
    let domain: String
    let type: PermissionType

    private var completionHandler: ((PermissionAuthorizationQuery?, Bool) -> Void)?

    init(domain: String, type: PermissionType, completionHandler: @escaping (PermissionAuthorizationQuery?, Bool) -> Void) {
        self.domain = domain
        self.type = type
        self.completionHandler = completionHandler
    }

    func handleDecision(grant: Bool) {
        completionHandler?(self, grant)
        completionHandler = nil
    }

    deinit {
        if let completionHandler = completionHandler {
            DispatchQueue.main.async {
                completionHandler(nil, false)
            }
        }
    }

}

enum PermissionState {
    case active
    case paused

    init?(isActive: Bool, isPaused: Bool) {
        switch (isActive, isPaused) {
        case (true, false):
            self = .active
        case (true, true):
            self = .paused
        case (false, _):
            return nil
        }
    }

    @available(macOS 12.0, *)
    init?(mediaCaptureState: WKMediaCaptureState) {
        switch mediaCaptureState {
        case .active:
            self = .active
        case .muted:
            self = .paused
        case .none: fallthrough
        @unknown default:
            return nil
        }
    }

    var isPaused: Bool {
        self == .paused
    }

}

struct Permissions {
    var permissions = [PermissionType: PermissionState]()

    var microphone: PermissionState? {
        get {
            permissions[.microphone]
        }
        set {
            permissions[.microphone] = newValue
        }
    }
    var camera: PermissionState? {
        get {
            permissions[.camera]
        }
        set {
            permissions[.camera] = newValue
        }
    }
    var sound: PermissionState? {
        get {
            permissions[.sound]
        }
        set {
            permissions[.sound] = newValue
        }
    }
    var geolocation: PermissionState? {
        get {
            permissions[.geolocation]
        }
        set {
            permissions[.geolocation] = newValue
        }
    }

    init() {}

    init(mediaCaptureState: _WKMediaCaptureStateDeprecated) {
        if mediaCaptureState.contains(.activeMicrophone) {
            self.microphone = .active
        } else if mediaCaptureState.contains(.mutedMicrophone) {
            self.microphone = .paused
        }
        if mediaCaptureState.contains(.activeCamera) {
            self.camera = .active
        } else if mediaCaptureState.contains(.mutedCamera) {
            self.camera = .paused
        }
    }

    @available(macOS 12, *)
    init(microphoneCaptureState: WKMediaCaptureState, cameraCaptureState: WKMediaCaptureState, soundState: WKMediaCaptureState) {
        self.microphone = PermissionState(mediaCaptureState: microphoneCaptureState)
        self.camera = PermissionState(mediaCaptureState: cameraCaptureState)
        self.sound = PermissionState(mediaCaptureState: soundState)
    }

}
