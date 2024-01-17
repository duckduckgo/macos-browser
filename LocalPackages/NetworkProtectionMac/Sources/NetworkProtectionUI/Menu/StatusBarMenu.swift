//
//  StatusBarMenu.swift
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

/// Abstraction of the the Network Protection status bar menu with a simple interface.
///
@objc
public final class StatusBarMenu: NSObject {
    public typealias MenuItem = NetworkProtectionStatusView.Model.MenuItem

    private let model: StatusBarMenuModel

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
    @MainActor
    public init(model: StatusBarMenuModel,
                statusItem: NSStatusItem? = nil,
                onboardingStatusPublisher: OnboardingStatusPublisher,
                statusReporter: NetworkProtectionStatusReporter,
                controller: TunnelController,
                iconProvider: IconProvider,
                showLocationsAction: @escaping () async -> Void,
                menuItems: @escaping () -> [MenuItem]) {

        self.model = model
        let statusItem = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem
        self.iconPublisher = NetworkProtectionIconPublisher(statusReporter: statusReporter, iconProvider: iconProvider)

        popover = NetworkProtectionPopover(controller: controller,
                                           onboardingStatusPublisher: onboardingStatusPublisher,
                                           statusReporter: statusReporter,
                                           showLocationsAction: showLocationsAction,
                                           menuItems: menuItems)
        popover.behavior = .transient

        super.init()

        statusItem.button?.image = .image(for: iconPublisher.icon)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusBarButtonTapped)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        subscribeToIconUpdates()
    }

    @objc
    private func statusBarButtonTapped() {
        let isOptionKeyPressed = NSApp.currentEvent?.modifierFlags.contains(.option) ?? false
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp

        guard !isRightClick else {
            showContextMenu()
            return
        }

        togglePopover(isOptionKeyPressed: isOptionKeyPressed)
    }

    private func subscribeToIconUpdates() {
        iconPublisherCancellable = iconPublisher.$icon
            .receive(on: DispatchQueue.main)
            .sink { [weak self] icon in

            self?.statusItem.button?.image = .image(for: icon)
        }
    }

    // MARK: - Popover

    private func togglePopover(isOptionKeyPressed: Bool) {
        if popover.isShown {
            popover.close()
        } else {
            guard let button = statusItem.button else {
                return
            }

            popover.setShowsDebugInformation(isOptionKeyPressed)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        }
    }

    // MARK: - Context

    private func showContextMenu() {
        if popover.isShown {
            popover.close()
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.items = model.contextMenuItems

        menu.popUp(positioning: nil,
                   at: .zero,
                   in: statusItem.button)
    }

    // MARK: - Showing & Hiding the menu

    public func show() {
        statusItem.isVisible = true
    }

    public func hide() {
        statusItem.isVisible = false
    }
}

extension StatusBarMenu: NSMenuDelegate {
    public func menuDidClose(_ menu: NSMenu) {
        // We need to remove the context menu when it's closed because otherwise
        // macOS will bypass our custom click-handling code and will proceed directly
        // to always showing the context menu (ignoring if it's a left or right click).
        statusItem.menu = nil
    }
}
