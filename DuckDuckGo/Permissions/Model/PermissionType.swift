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

// S NS
// 0 0
// 0 1
// 1 x
// 1 x

enum PermissionType: Hashable {
    private enum Constants: String {
        case camera
        case microphone
        case geolocation
        case popups
        case external = "external_"
        case autoplayWithoutSound
        case autoplayWithSound
    }

    case camera
    case microphone
    case geolocation
    case popups
    case externalScheme(scheme: String)
    case autoplayWithoutSound
    case autoplayWithSound

    var rawValue: String {
        switch self {
        case .camera: return Constants.camera.rawValue
        case .microphone: return Constants.microphone.rawValue
        case .geolocation: return Constants.geolocation.rawValue
        case .popups: return Constants.popups.rawValue
        case .externalScheme(scheme: let scheme): return Constants.external.rawValue + scheme
        case .autoplayWithoutSound: return Constants.autoplayWithoutSound.rawValue
        case .autoplayWithSound: return Constants.autoplayWithSound.rawValue
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case Constants.camera.rawValue: self = .camera
        case Constants.microphone.rawValue: self = .microphone
        case Constants.geolocation.rawValue: self = .geolocation
        case Constants.popups.rawValue: self = .popups
        case Constants.autoplayWithoutSound.rawValue: self = .autoplayWithoutSound
        case Constants.autoplayWithSound.rawValue: self = .autoplayWithSound
        default:
            if rawValue.hasPrefix(Constants.external.rawValue) {
                let scheme = rawValue.dropping(prefix: Constants.external.rawValue)
                guard !scheme.isEmpty else { return nil }
                self = .externalScheme(scheme: scheme)
                return
            }
            return nil
        }
    }
}

extension PermissionType {

    static var permissionsUpdatedExternally: [PermissionType] {
        return [.camera, .microphone, .geolocation]
    }

    var canPersistGrantedDecision: Bool {
        switch self {
        case .camera, .microphone, .externalScheme, .autoplayWithSound, .autoplayWithoutSound:
            return true
        case .geolocation:
            return false
        case .popups:
            return true
        }
    }
    var canPersistDeniedDecision: Bool {
        switch self {
        case .camera, .microphone, .geolocation, .autoplayWithSound, .autoplayWithoutSound:
            return true
        case .popups, .externalScheme:
            return false
        }
    }

    var isExternalScheme: Bool {
        if case .externalScheme = self {
            return true
        }
        return false
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
            // https://app.asana.com/0/1177771139624306/1201416749093968
            // result.append(.display)
        }
        guard !result.isEmpty else { return nil }
        self = result
    }

    static var camera: Self { [.camera] }
    static var microphone: Self { [.microphone] }
    static var geolocation: Self { [.geolocation] }
    static var popups: Self { [.popups] }
    static var autoplay: Self { [.autoplayWithSound, .autoplayWithoutSound] }
    static func externalScheme(_ scheme: String) -> Self { return [.externalScheme(scheme: scheme)] }

}
