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
import os.log

final class MainWindow: NSWindow {

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
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
        autorecalculatesKeyViewLoop = false
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

    override func _postNeedsUpdateConstraintsUnlessPostingDisabled() {
        do {
            try NSException.catch {
                super._postNeedsUpdateConstraintsUnlessPostingDisabled()
            }
        } catch {
            os_log("Exception thrown in _postNeedsUpdateConstraintsUnlessPostingDisabled: %s", "\(error)")
        }
    }

    override func _postNeedsLayoutUnlessPostingDisabled() {
        do {
            try NSException.catch {
                super._postNeedsLayoutUnlessPostingDisabled()
            }
        } catch {
            os_log("Exception thrown in _postNeedsLayoutUnlessPostingDisabled: %s", "\(error)")
        }
    }

    override func _postNeedsDisplayUnlessPostingDisabled() {
        do {
            try NSException.catch {
                super._postNeedsDisplayUnlessPostingDisabled()
            }
        } catch {
            os_log("Exception thrown in _postNeedsDisplayUnlessPostingDisabled: %s", "\(error)")
        }
    }

    override func _updateStructuralRegionsOnNextDisplayCycle() {
        do {
            try NSException.catch {
                super._updateStructuralRegionsOnNextDisplayCycle()
            }
        } catch {
            os_log("Exception thrown in _updateStructuralRegionsOnNextDisplayCycle: %s", "\(error)")
        }
    }

}

extension Notification.Name {
    static let firstResponder = Notification.Name("firstResponder")
}
