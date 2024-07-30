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
import NetworkProtection
import LoginItems

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

    private let debugInformationPublisher = CurrentValueSubject<Bool, Never>(false)
    private let statusReporter: NetworkProtectionStatusReporter
    private let siteTroubleshootingViewModel: SiteTroubleshootingView.Model
    private let model: NetworkProtectionStatusView.Model
    private var appLifecycleCancellables = Set<AnyCancellable>()

    public required init(controller: TunnelController,
                         onboardingStatusPublisher: OnboardingStatusPublisher,
                         statusReporter: NetworkProtectionStatusReporter,
                         siteTroubleshootingViewModel: SiteTroubleshootingView.Model,
                         uiActionHandler: VPNUIActionHandling,
                         menuItems: @escaping () -> [MenuItem],
                         agentLoginItem: LoginItem?,
                         isMenuBarStatusView: Bool,
                         userDefaults: UserDefaults,
                         locationFormatter: VPNLocationFormatting,
                         uninstallHandler: @escaping () async -> Void) {

        self.statusReporter = statusReporter
        self.siteTroubleshootingViewModel = siteTroubleshootingViewModel
        self.model = NetworkProtectionStatusView.Model(controller: controller,
                                                       onboardingStatusPublisher: onboardingStatusPublisher,
                                                       statusReporter: statusReporter,
                                                       debugInformationPublisher: debugInformationPublisher.eraseToAnyPublisher(),
                                                       uiActionHandler: uiActionHandler,
                                                       menuItems: menuItems,
                                                       agentLoginItem: agentLoginItem,
                                                       isMenuBarStatusView: isMenuBarStatusView,
                                                       userDefaults: userDefaults,
                                                       locationFormatter: locationFormatter,
                                                       uninstallHandler: uninstallHandler)

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
        let view = NetworkProtectionStatusView(model: self.model).environment(\.dismiss, { [weak self] in
            self?.close()
        }).fixedSize()
            .environmentObject(siteTroubleshootingViewModel)

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
            .sink { [weak self] _ in self?.model.refreshLoginItemStatus() }
            .store(in: &appLifecycleCancellables)

        NotificationCenter
            .default
            .publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in self?.closePopoverIfOnboarded() }
            .store(in: &appLifecycleCancellables)
    }

    private func closePopoverIfOnboarded() {
        if self.model.onboardingStatus == .completed {
            self.close()
        }
    }

    override public func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        statusReporter.forceRefresh()
        model.refreshLoginItemStatus()
        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }

    // MARK: - Debug Information

    func setShowsDebugInformation(_ showsDebugInformation: Bool) {
        debugInformationPublisher.send(showsDebugInformation)
    }
}
