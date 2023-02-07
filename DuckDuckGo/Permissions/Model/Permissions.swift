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

    var geolocation: PermissionState? {
        get {
            self[.geolocation]
        }
        set {
            self[.geolocation] = newValue
        }
    }

    var popups: PermissionState? {
        get {
            self[.popups]
        }
        set {
            self[.popups] = newValue
        }
    }

    var externalScheme: PermissionState? {
        return self.first(where: { $0.key.isExternalScheme })?.value
    }

}
