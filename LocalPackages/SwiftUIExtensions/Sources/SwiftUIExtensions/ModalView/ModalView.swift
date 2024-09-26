//
//  ModalView.swift
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
import SwiftUI

public protocol ModalView: View {}

public extension ModalView {

    /// Shows the view as a modal sheet if a parent window is provided, or as a standalone modal window
    /// if no parent window is provided.
    ///
    /// Showing alerts as stand alone modals can be useful when we don't have a window to attach to.
    /// As an example: this is useful for our VPN menu app which can't rely on having a parent window to show an
    /// alert.
    ///
    /// - Parameters:
    ///     parentWindow: the parent window to show this view as a modal sheet on.
    ///
    @MainActor
    func show(in parentWindow: NSWindow? = nil) async {

        var session: NSApplication.ModalSession?

        if let parentWindow {
            if !parentWindow.isKeyWindow {
                parentWindow.makeKeyAndOrderFront(nil)
            }
        }

        var capturedWeakWindow: NSWindow?

        let rootView = self.environment(\.dismiss, {
            guard let window = capturedWeakWindow else {
                return
            }

            if let session {
                NSApplication.shared.endModalSession(session)
                window.close()
            } else {
                parentWindow?.endSheet(window)
            }
        })

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.frame.size = hostingView.intrinsicContentSize

        // One might be tempted to use hostingView as the content view for the window,
        // but it doesn't deal properly with the window safe areas when setting the
        // the fullSizeContentView style mask in a modal window that's hiding it's title.
        //
        // I'm creating a content view that wraps the NSHostingView and clips the unnecessary
        // safe area.
        //
        // To reproduce the issues I was seeing:
        //  1. Make the hosting view the window's content view.
        //  2. Show the window modally (not as a sheet).
        //  3. See that the safe area in the window is off.
        //  4. Repeat the test with this intermediate content view and see it's fixed.
        //
        let contentView = NSView(frame: NSRect(origin: .zero, size: hostingView.intrinsicContentSize))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hostingView)

        let window = NSWindow(contentRect: contentView.frame, styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.toolbar = nil
        window.hidesOnDeactivate = false
        window.level = .floating
        window.contentView = contentView

        // When shown as a modal alert the app crashes without this.
        // To test: comment this line, and make the alert come up as a standalone
        // modal alert (not as a sheet).
        //
        // We'll just let ARC destroy the window once it's no longer referenced.
        //
        window.isReleasedWhenClosed = false

        capturedWeakWindow = window

        if let parentWindow {
            await parentWindow.beginSheet(window)
        } else {
            session = NSApplication.shared.beginModalSession(for: window)
        }
    }

}
