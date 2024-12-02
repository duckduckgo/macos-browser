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
import Combine
import Foundation
import SwiftUI
import SwiftUIExtensions
import NetworkProtection
import LoginItems

public final class NetworkProtectionPopover: NSPopover {

    public typealias MenuItem = NetworkProtectionStatusView.Model.MenuItem

    private let statusReporter: NetworkProtectionStatusReporter
    private let debugInformationViewModel: DebugInformationViewModel
    private let siteTroubleshootingViewModel: SiteTroubleshootingView.Model
    private let statusViewModel: NetworkProtectionStatusView.Model
    private let tipsModel: VPNTipsModel
    private var appLifecycleCancellables = Set<AnyCancellable>()

    public required init(statusViewModel: NetworkProtectionStatusView.Model,
                         statusReporter: NetworkProtectionStatusReporter,
                         siteTroubleshootingViewModel: SiteTroubleshootingView.Model,
                         tipsModel: VPNTipsModel,
                         debugInformationViewModel: DebugInformationViewModel) {

        self.statusReporter = statusReporter
        self.debugInformationViewModel = debugInformationViewModel
        self.siteTroubleshootingViewModel = siteTroubleshootingViewModel
        self.tipsModel = tipsModel
        self.statusViewModel = statusViewModel

        super.init()

        self.animates = false
        self.behavior = .semitransient

        subscribeToAppLifecycleEvents()
        setupContentController()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContentController() {
        let view = NetworkProtectionStatusView()
            .environmentObject(debugInformationViewModel)
            .environmentObject(siteTroubleshootingViewModel)
            .environmentObject(statusViewModel)
            .environmentObject(tipsModel)
            .environment(\.dismiss, { [weak self] in
            self?.close()
        }).fixedSize()

        let controller = NSHostingController(rootView: view)
        contentViewController = controller

        // It's important to set the frame at least once here.  If we don't the popover
        // fails to get the right width and the popover can exceed the screen's limits.
        controller.view.frame = CGRect(origin: .zero, size: controller.view.intrinsicContentSize)
    }

    // MARK: - Status Refresh

    private func subscribeToAppLifecycleEvents() {
        NotificationCenter
            .default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.statusViewModel.refreshLoginItemStatus() }
            .store(in: &appLifecycleCancellables)

        NotificationCenter
            .default
            .publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in self?.closePopoverIfOnboarded() }
            .store(in: &appLifecycleCancellables)
    }

    private func closePopoverIfOnboarded() {
        if self.statusViewModel.onboardingStatus == .completed {
            self.close()
        }
    }

    override public func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {

        // Starting on macOS sequoia this is necessary to make sure the popover has focus
        NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)

        statusReporter.forceRefresh()
        statusViewModel.refreshLoginItemStatus()
        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }
}
