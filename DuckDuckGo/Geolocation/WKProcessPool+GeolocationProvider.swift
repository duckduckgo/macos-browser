//
//  WKProcessPool+GeolocationProvider.swift
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

import WebKit

extension WKProcessPool {
    private static let geolocationProviderKey = UnsafeRawPointer(bitPattern: "WKProcessPoolGeolocationProviderKey".hashValue)!

    @nonobjc var geolocationProvider: GeolocationProviderProtocol? {
        get {
            return objc_getAssociatedObject(self, Self.geolocationProviderKey) as? GeolocationProviderProtocol
        }
        set {
            objc_setAssociatedObject(self, Self.geolocationProviderKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

}
