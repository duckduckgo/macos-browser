//
//  MainWindow.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

import Cocoa

final class MainWindow: NSWindow {

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }

    var mainViewController: MainViewController? {
        guard let mainViewController = contentViewController as? MainViewController else {
            assertionFailure("Unexpected View Controller type")
            return nil
        }
        return mainViewController
    }

    init(frame: NSRect) {
        super.init(contentRect: frame,
                   styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                   backing: .buffered,
                   defer: true)

        setupWindow()
    }

    private func setupWindow() {
        allowsToolTipsWhenApplicationIsInactive = false
        autorecalculatesKeyViewLoop = true
        isReleasedWhenClosed = false
        animationBehavior = .documentWindow
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        // the window will be draggable using custom drag areas defined by WindowDraggingView
        isMovable = false
    }

    // MARK: - First Responder Notification

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        // The only reliable way to detect NSTextField is the first responder
        defer {
            // Send it after the first responder has been set on the super class so that window.firstResponder matches correctly
            postFirstResponderNotification(with: responder)
        }
        
        return super.makeFirstResponder(responder)
    }

    override func becomeMain() {
        super.becomeMain()

        postFirstResponderNotification(with: firstResponder)
    }

    override func endEditing(for object: Any?) {
        if case .leftMouseUp = NSApp.currentEvent?.type,
           object is AddressBarTextEditor {
            // prevent deactivation of Address Bar on Toolbar click
            return
        }

        super.endEditing(for: object)
    }

    private func postFirstResponderNotification(with firstResponder: NSResponder?) {
        NotificationCenter.default.post(name: .firstResponder, object: firstResponder)
    }

    var newTabButton: NSButton? {
        mainViewController?.tabBarViewController.plusButton
    }

    override func accessibilityChildren() -> [Any]? {
        var children = super.accessibilityChildren() as? [NSObject] ?? []
        let newTabButton = self.newTabButton
        if let newTabIdx = children.firstIndex(where: { $0 === newTabButton?.cell }) {
            children.remove(at: newTabIdx)
        }
        return children
    }
    
    // Handle Keyboard toggle Toolbar focus (Ctrl+F5)
    @objc(_handleFocusToolbarHotKey:)
    func handleFocusToolbarHotKey(_ event: Any?) {
        guard mainViewController?.children.isEmpty != false else {
            return
        }
        mainViewController?.toggleToolbarFocus()
    }

    override func recalculateKeyViewLoop() {
        mainViewController?.tabBarViewController.view.superview?.setDefaultKeyViewLoop()
        super.recalculateKeyViewLoop()

        mainViewController?.webContainerView.nextKeyView = mainViewController?.tabBarViewController.view
        mainViewController?.tabBarViewController.view.nextKeyView = mainViewController?.navigationBarViewController.view.nextKeyView
    }

}

extension Notification.Name {
    static let firstResponder = Notification.Name("firstResponder")
}
