//
//  PermissionType.swift
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

enum PermissionType: String, CaseIterable {
    case camera
    case microphone
    case geolocation
    case popups
}

extension PermissionType {
    var canPersistGrantedDecision: Bool {
        switch self {
        case .camera, .microphone:
            return true
        case .geolocation:
            return false
        case .popups:
            return true
        }
    }
}

extension Array where Element == PermissionType {

    @available(OSX 12, *)
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
            assertionFailure("Unexpected permission")
        }
        guard !result.isEmpty else { return nil }
        self = result
    }

}
