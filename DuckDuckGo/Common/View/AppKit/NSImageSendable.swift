//
//  NSImageSendable.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import AppKit

struct NSImageSendable: @unchecked Sendable, _ObjectiveCBridgeable {
    private let image: NSImage

    // swiftlint:disable identifier_name
    func _bridgeToObjectiveC() -> NSImage {
        image
    }

    static func _forceBridgeFromObjectiveC(_ source: NSImage, result: inout NSImageSendable?) {
        result = NSImageSendable(image: source)
    }

    static func _conditionallyBridgeFromObjectiveC(_ source: NSImage, result: inout NSImageSendable?) -> Bool {
        result = NSImageSendable(image: source)
        return true
    }

    static func _unconditionallyBridgeFromObjectiveC(_ source: NSImage?) -> NSImageSendable {
        NSImageSendable(image: source!)
    }
    // swiftlint:enable identifier_name

}
