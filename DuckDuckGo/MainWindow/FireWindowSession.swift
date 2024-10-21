//
//  FireWindowSession.swift
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

/// Represents a “Fire Window Session” tracking lifetime of the owning Fire Window and Popup windows created from it.
/// Used to detect active downloads within a Fire Window Session.
/// Deinitialized when the last window from the session is closed calling the `deinitObservers`.
@MainActor final class FireWindowSession {
    private struct WindowRef: Hashable {
        weak var window: NSWindow?
        private let identifier: ObjectIdentifier

        init(window: NSWindow) {
            self.window = window
            self.identifier = ObjectIdentifier(window)
        }

        static func == (lhs: WindowRef, rhs: WindowRef) -> Bool {
            lhs.identifier == rhs.identifier
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(identifier)
        }
    }
    private var windowRefs: Set<WindowRef> = []
    private var deinitObservers: [() -> Void] = []

    var windows: [NSWindow] {
        windowRefs.reduce(into: []) { result, windowRef in
            guard let window = windowRef.window else { return }
            result.append(window)
        }
    }

    var isActive: Bool {
        windowRefs.contains(where: { $0.window?.isVisible == true })
    }

    func addWindow(_ window: NSWindow) {
        windowRefs.insert(WindowRef(window: window))
    }

    public func onDeinit(_ onDeinit: @escaping () -> Void) {
        deinitObservers.append(onDeinit)
    }

    deinit {
        for deinitObserver in deinitObservers {
            deinitObserver()
        }
    }
}

struct FireWindowSessionRef: Hashable {

    private(set) weak var fireWindowSession: FireWindowSession?
    private let identifier: ObjectIdentifier

    @MainActor
    var isActive: Bool {
        fireWindowSession?.isActive ?? false
    }

    @MainActor
    init?(window: NSWindow?) {
        guard let window else { return nil }
        guard let mainWindowController = window.windowController as? MainWindowController else {
            assertionFailure("\(window) has no MainWindowController")
            return nil
        }
        guard let fireWindowSession = mainWindowController.fireWindowSession else { return nil }
        self.fireWindowSession = fireWindowSession
        self.identifier = ObjectIdentifier(fireWindowSession)
    }

    @MainActor
    public func onBurn(_ burnHandler: @escaping () -> Void) {
        fireWindowSession?.onDeinit(burnHandler) ?? burnHandler()
    }

    static func == (lhs: FireWindowSessionRef, rhs: FireWindowSessionRef) -> Bool {
        lhs.identifier == rhs.identifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
