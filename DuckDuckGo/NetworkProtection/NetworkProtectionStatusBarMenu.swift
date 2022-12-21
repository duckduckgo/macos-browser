//
//  NetworkProtectionStatusBarMenu.swift
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

import Foundation
import SwiftUI

/// Abstraction of the the Network Protection status bar menu with a simple interface.
///
final class NetworkProtectionStatusBarMenu {
    private let statusItem: NSStatusItem

    // MARK: - Initialization

    /// Default initializer
    ///
    /// - Parameters:
    ///     - statusItem: (meant for testing) this allows us to inject our own status `NSStatusItem` to make automated testing easier..
    ///
    init(statusItem: NSStatusItem? = nil) {
        self.statusItem = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let item = NSMenuItem()
        let model = NetworkProtectionStatusView.Model(runLoopMode: .eventTracking)
        let view = NetworkProtectionStatusView(model: model)
        let hostingView = NSHostingView(rootView: view)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.autoresizesSubviews = false
        hostingView.frame.size = hostingView.intrinsicContentSize
        item.view = hostingView

        let menu = NSMenu(items: [item])
        self.statusItem.menu = menu
        self.statusItem.button?.image = .init(.vpnIcon)
    }

    // MARK: - Showing & Hiding the menu

    func show() {
        statusItem.isVisible = true
    }

    func hide() {
        statusItem.isVisible = false
    }
}
