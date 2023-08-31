//
//  NSEventExtension.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import Combine

extension NSEvent {

    /// is NSEvent representing right mouse down event or cntrl+mouse down event
    static func isContextClick(_ event: NSEvent) -> Bool {
        let isControlClick = event.type == .leftMouseDown && (event.modifierFlags.rawValue & NSEvent.ModifierFlags.control.rawValue != 0)
        let isRightClick = event.type == .rightMouseDown
        return isControlClick || isRightClick
    }

    /// `addGlobalMonitorForEventsMatchingMask:handler:` with automatic unsubscribe
    /// - Returns: AnyCancellable removing the monitor on `.cancel()` or `deinit`
    static func addGlobalCancellableMonitor(forEventsMatching mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) -> AnyCancellable {
        let monitor = addGlobalMonitorForEvents(matching: mask, handler: handler)
        return AnyCancellable {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }

    /// `addLocalMonitorForEventsMatchingMask:handler:` with automatic unsubscribe
    /// - Returns: AnyCancellable removing the monitor on `.cancel()` or `deinit`
    static func addLocalCancellableMonitor(forEventsMatching mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> NSEvent?) -> AnyCancellable {
        let monitor = addLocalMonitorForEvents(matching: mask, handler: handler)
        return AnyCancellable {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }

}
