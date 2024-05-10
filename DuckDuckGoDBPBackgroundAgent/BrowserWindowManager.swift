//
//  BrowserWindowManager.swift
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
import Foundation
import WebKit

/// A class that offers functionality to quickly show an interactive browser window.
///
/// This class is meant to aid with debugging and should not be included in release builds.
/// .
final class BrowserWindowManager: NSObject {
    private var interactiveBrowserWindow: NSWindow?

    @MainActor
    func show(domain: String) {
        if let interactiveBrowserWindow, interactiveBrowserWindow.isVisible {
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.title = "Web Browser"
        window.delegate = self
        interactiveBrowserWindow = window

        // Create the WKWebView.
        let webView = WKWebView(frame: window.contentView!.bounds)
        webView.autoresizingMask = [.width, .height]
        window.contentView!.addSubview(webView)

        // Load a URL.
        let url = URL(string: domain)!
        let request = URLRequest(url: url)
        webView.load(request)

        // Show the window.
        window.makeKeyAndOrderFront(nil)
    }
}

extension BrowserWindowManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        interactiveBrowserWindow = nil
    }
}
