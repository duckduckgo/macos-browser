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

import AppKit
import Foundation
import Combine
import SwiftUI
import NetworkProtection
import os.log

/// Abstraction of the the Network Protection status bar menu with a simple interface.
///
public final class StatusBarMenu {
    private let statusItem: NSStatusItem

    private let popover: NetworkProtectionPopover

    // MARK: - NetP Icon publisher

    private let iconPublisher: NetworkProtectionIconPublisher
    private var iconPublisherCancellable: AnyCancellable?

    // MARK: - Initialization

    /// Default initializer
    ///
    /// - Parameters:
    ///     - statusItem: (meant for testing) this allows us to inject our own status `NSStatusItem` to make automated testing easier..
    ///
    public init(statusItem: NSStatusItem? = nil,
                statusReporter: NetworkProtectionStatusReporter? = nil) {

        let statusReporter = statusReporter ?? DefaultNetworkProtectionStatusReporter(
            statusObserver: ConnectionStatusObserverThroughIPC(),
            serverInfoObserver: ConnectionServerInfoObserverThroughIPC(),
            connectionErrorObserver: ConnectionErrorObserverThroughIPC())

        self.statusItem = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.iconPublisher = NetworkProtectionIconPublisher(statusReporter: statusReporter)

        let parentBundlePath = "../../../../"
        let url: URL

        if #available(macOS 13, *) {
            url = URL(filePath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
        } else {
            url = URL(fileURLWithPath: parentBundlePath, relativeTo: Bundle.main.bundleURL)
        }

        let controller = AppLaunchingController(appBundleURL: url)

        popover = NetworkProtectionPopover(controller: controller, statusReporter: statusReporter, showLaunchBrowserMenuItem: true)
        popover.behavior = .transient

        self.statusItem.button?.image = .image(for: iconPublisher.icon)
        self.statusItem.button?.target = self
        self.statusItem.button?.action = #selector(statusBarButtonTapped)

        subscribeToIconUpdates()
    }

    @objc
    private func statusBarButtonTapped() {
        if popover.isShown {
            popover.close()
        } else {
            guard let button = statusItem.button else {
                return
            }

            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        }
    }

    private func subscribeToIconUpdates() {
        iconPublisherCancellable = iconPublisher.$icon.sink { [weak self] icon in
            self?.statusItem.button?.image = .image(for: icon)
        }
    }

    // MARK: - Showing & Hiding the menu

    public func show() {
        statusItem.isVisible = true
    }

    public func hide() {
        statusItem.isVisible = false
    }
}
