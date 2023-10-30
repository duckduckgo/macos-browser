//
//  WaitlistModalViewController.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

#if NETWORK_PROTECTION

import AppKit
import SwiftUI
import UserNotifications

extension Notification.Name {
    static let waitlistModalViewControllerShouldDismiss = Notification.Name(rawValue: "waitlistModalViewControllerShouldDismiss")
}

final class WaitlistModalViewController: NSViewController {

    // Small hack to force the waitlist modal view controller to dismiss all instances of itself whenever the user opens a link from the T&C view.
    static func dismissWaitlistModalViewControllerIfNecessary(_ url: URL) {
        if ["https://duckduckgo.com/privacy", "https://duckduckgo.com/terms"].contains(url.absoluteString) {
            NotificationCenter.default.post(name: .waitlistModalViewControllerShouldDismiss, object: nil)
        }
    }

    private let defaultSize = CGSize(width: 360, height: 650)
    private let model: NetworkProtectionWaitlistViewModel

    private var heightConstraint: NSLayoutConstraint?

    init(notificationPermissionState: NetworkProtectionWaitlistViewModel.NotificationPermissionState) {
        self.model = NetworkProtectionWaitlistViewModel(waitlist: NetworkProtectionWaitlist(),
                                                        notificationPermissionState: notificationPermissionState,
                                                        termsAndConditionActionHandler: NetworkProtectionWaitlistTermsAndConditionsActionHandler(),
                                                        featureSetupHandler: NetworkProtectionWaitlistFeatureSetupHandler())
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        view = NSView(frame: NSRect(origin: CGPoint.zero, size: defaultSize))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.model.delegate = self

        let waitlistRootView = WaitlistRootView()

        let hostingView = NSHostingView(rootView: waitlistRootView.environmentObject(self.model))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingView)

        let heightConstraint = hostingView.heightAnchor.constraint(equalToConstant: defaultSize.height)
        self.heightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            heightConstraint,
            hostingView.widthAnchor.constraint(equalToConstant: defaultSize.width),
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingView.leftAnchor.constraint(equalTo: view.leftAnchor),
            hostingView.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(dismissModal), name: .waitlistModalViewControllerShouldDismiss, object: nil)
    }

    private func updateViewHeight(height: CGFloat) {
        heightConstraint?.constant = height
    }

    static func show(completion: (() -> Void)? = nil) {
        guard let windowController = WindowControllersManager.shared.lastKeyMainWindowController,
              windowController.window?.isKeyWindow == true else {
            return
        }

        // This is a hack to get around an issue with the waitlist notification screen showing the wrong state while it animates in, and then
        // jumping to the correct state as soon as the animation is complete. This works around that problem by providing the correct state up front,
        // preventing any state changing from occurring.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            let state = NetworkProtectionWaitlistViewModel.NotificationPermissionState.from(status)

            DispatchQueue.main.async {
                let viewController = WaitlistModalViewController(notificationPermissionState: state)
                windowController.mainViewController.beginSheet(viewController) { _ in
                    completion?()
                }
            }
        }
    }

}

extension WaitlistModalViewController: WaitlistViewModelDelegate {

    @objc
    func dismissModal() {
        self.dismiss()
    }

    func viewHeightChanged(newHeight: CGFloat) {
        updateViewHeight(height: newHeight)
    }

}

#endif
