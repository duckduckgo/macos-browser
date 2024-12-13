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

public extension NSEvent {

    struct EventMonitorType: OptionSet {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public static let local  = EventMonitorType(rawValue: 1 << 0)
        public static let global = EventMonitorType(rawValue: 1 << 1)
    }

    var deviceIndependentFlags: NSEvent.ModifierFlags {
        modifierFlags.intersection(.deviceIndependentFlagsMask)
    }

    typealias KeyEquivalent = Set<KeyEquivalentElement>

    var keyEquivalent: KeyEquivalent? {
        KeyEquivalent(event: self)
    }

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

    static func publisher(forEvents monitorType: EventMonitorType, matching mask: NSEvent.EventTypeMask) -> AnyPublisher<NSEvent, Never> {
        let subject = PassthroughSubject<NSEvent, Never>()
        var cancellables = Set<AnyCancellable>()
        if monitorType.contains(.local) {
            addLocalCancellableMonitor(forEventsMatching: mask) { event in
                subject.send(event)
                return event
            }.store(in: &cancellables)
        }
        if monitorType.contains(.global) {
            addGlobalCancellableMonitor(forEventsMatching: mask) { event in
                subject.send(event)
            }.store(in: &cancellables)
        }

        return subject
            .handleEvents(receiveCancel: {
                cancellables.forEach { $0.cancel() }
            })
            .eraseToAnyPublisher()
    }

}

public enum KeyEquivalentElement: ExpressibleByStringLiteral, Hashable {
    public typealias StringLiteralType = String

    case charCode(String)
    case command
    case shift
    case option
    case control

    public static let backspace = KeyEquivalentElement.charCode("\u{8}")
    public static let tab = KeyEquivalentElement.charCode("\t")
    public static let left = KeyEquivalentElement.charCode("\u{2190}")
    public static let right = KeyEquivalentElement.charCode("\u{2192}")
    public static let escape = KeyEquivalentElement.charCode("\u{1B}")

    public init(stringLiteral value: String) {
        self = .charCode(value)
    }
}

extension NSEvent.KeyEquivalent: ExpressibleByStringLiteral, ExpressibleByUnicodeScalarLiteral, ExpressibleByExtendedGraphemeClusterLiteral {
    public typealias StringLiteralType = String

    public static let backspace: Self = [.backspace]
    public static let tab: Self = [.tab]
    public static let left: Self = [.left]
    public static let right: Self = [.right]
    public static let escape: Self = [.escape]

    public init(stringLiteral value: String) {
        self = [.charCode(value)]
    }

    init?(event: NSEvent) {
        guard [.keyDown, .keyUp].contains(event.type) else {
            assertionFailure("wrong type of event \(event)")
            return nil
        }
        guard let characters = event.characters else { return nil }
        self = [.charCode(characters)]
        if event.modifierFlags.contains(.command) {
            self.insert(.command)
        }
        if event.modifierFlags.contains(.shift) {
            self.insert(.shift)
        }
        if event.modifierFlags.contains(.option) {
            self.insert(.option)
        }
        if event.modifierFlags.contains(.control) {
            self.insert(.control)
        }
    }

    public var charCode: String {
        for item in self {
            if case .charCode(let value) = item {
                return value
            }
        }
        return ""
    }

    public var modifierMask: NSEvent.ModifierFlags {
        var result: NSEvent.ModifierFlags = []
        for item in self {
            switch item {
            case .charCode: continue
            case .command:
                result.insert(.command)
            case .shift:
                result.insert(.shift)
            case .option:
                result.insert(.option)
            case .control:
                result.insert(.control)
            }
        }
        return result
    }

}
