//
//  NetworkProtectionPopover.swift
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
import SwiftUI
import NetworkProtection

@available(iOS, introduced: 10.15, deprecated: 12.0, message: "Use Apple's DismissAction")
public struct DismissAction: EnvironmentKey {
    public static var defaultValue: () -> Void = {}
}

@available(iOS, introduced: 10.15, deprecated: 12.0, message: "Use Apple's DismissAction")
public extension EnvironmentValues {
    var dismiss: () -> Void {
        get {
            self[DismissAction.self]
        }

        set {
            self[DismissAction.self] = newValue
        }
    }
}

public final class NetworkProtectionPopover: NSPopover {

    public typealias MenuItem = NetworkProtectionStatusView.Model.MenuItem

    private let statusReporter: NetworkProtectionStatusReporter

    public required init(controller: TunnelController, statusReporter: NetworkProtectionStatusReporter, menuItems: [MenuItem]) {

        self.statusReporter = statusReporter

        super.init()

        self.animates = false
        self.behavior = .semitransient

        setupContentController(controller: controller, statusReporter: statusReporter, menuItems: menuItems)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContentController(controller: TunnelController, statusReporter: NetworkProtectionStatusReporter, menuItems: [MenuItem]) {

        let model = NetworkProtectionStatusView.Model(controller: controller,
                                                      statusReporter: statusReporter,
                                                      menuItems: menuItems)

        let controller: NSViewController

        let view = NetworkProtectionStatusView(model: model).environment(\.dismiss, { [weak self] in
            self?.close()
        })
        controller = NSHostingController(rootView: view)

        contentViewController = controller

        // It's important to set the frame at least once here.  If we don't the popover
        // fails to get the right width and the popover can exceed the screen's limits.
        controller.view.frame = CGRect(origin: .zero, size: controller.view.intrinsicContentSize)
    }

    // MARK: - Forcing Status Refresh

    override public func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {

        statusReporter.forceRefresh()
        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }
}
