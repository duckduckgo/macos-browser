//
//  DuckChatStatusBar.swift
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

import Foundation
import AppKit

public final class DuckChatStatusBar: NSObject {
    public static let shared = DuckChatStatusBar()

    private var statusBarItem: NSStatusItem?
    private var popover: NSPopover?

    @UserDefaultsWrapper(key: .AIChatMenuItemEnabled, defaultValue: false)
    var menuItemEnabled: Bool {
        didSet {
            if menuItemEnabled {
                showStatusBarItem()
            } else {
                hideStatusBarItem()
            }
        }
    }

    override init() {
        super.init()
        if menuItemEnabled {
            loadStatusBar()
        }
    }

    private func loadStatusBar () {
        guard statusBarItem == nil, statusBarItem == nil else { return }
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "bubble.left.and.text.bubble.right", accessibilityDescription: nil) {
            statusBarItem?.button?.image = image
        }

        let contentView = ContentView()

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 500, height: 700)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: contentView)

        statusBarItem?.button?.target = self
        statusBarItem?.button?.action = #selector(togglePopover(_:))
    }

    private func showStatusBarItem() {
        loadStatusBar()
        statusBarItem?.isVisible = true
    }

    private func hideStatusBarItem() {
        statusBarItem?.isVisible = false
        statusBarItem = nil
    }

    @objc func togglePopover(_ sender: AnyObject) {
        guard let popover = popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            if let button = statusBarItem?.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
}

import SwiftUI
import WebKit

struct WebViewWrapper: NSViewRepresentable {
    let url: URL
    let header = "X-DuckDuckGo-Client"
    let headerValue = "macOS"

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.autoresizingMask = [.width, .height]
        webView.customUserAgent = UserAgent.safari

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        nsView.load(request)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewWrapper

        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor
                     navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            try? await webView.evaluateJavaScript("navigator.duckduckgo = {platform: 'macos'}")

            var request = navigationAction.request

            guard let url = request.url else { return .allow }

            guard navigationAction.targetFrame?.isMainFrame == true,
                  url.isDuckDuckGo else {
                return .allow
            }

            if request.value(forHTTPHeaderField: parent.header) == nil {
                request.setValue(parent.headerValue, forHTTPHeaderField: parent.header)
                print("SET HEADER")
                await webView.load(request)
            }
            return .allow
        }

        deinit {
            print("Web deinit")
        }
    }


}

struct ContentView: View {
    let customURL = URL(string: "https://use-devcpu1.duckduckgo.com/?ia=chat")!
    var body: some View {
            WebViewWrapper(url: customURL)
    }
}
