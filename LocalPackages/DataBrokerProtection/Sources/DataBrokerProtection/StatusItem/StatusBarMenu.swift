//
//  StatusBarMenu.swift
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

public final class StatusBarMenu: NSObject {
    private let statusItem: NSStatusItem
    private let popover: StatusBarPopover

    public override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = StatusBarPopover()
        popover.behavior = .transient
        super.init()

        setupStatusItem()
    }

    @objc
    private func statusBarButtonTapped() {
        togglePopover()
    }

    private func setupStatusItem() {
        statusItem.button?.target = self
        statusItem.button?.image = NSImage(systemSymbolName: NSImage.Name("person.crop.circle.badge.minus"), accessibilityDescription: nil)
        statusItem.button?.action = #selector(statusBarButtonTapped)
        statusItem.button?.sendAction(on: [.leftMouseUp])
    }

    // MARK: - Popover

    private func togglePopover() {
        if popover.isShown {
            popover.close()
        } else {
            guard let button = statusItem.button else {
                return
            }

            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            popover.contentViewController?.view.window?.makeKey()
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
