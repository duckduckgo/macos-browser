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

import AppKit
import SwiftUI

final class WaitlistModalViewController: NSViewController {

    private let defaultSize = CGSize(width: 360, height: 650)
    private let model = WaitlistViewModel(waitlist: NetworkProtectionWaitlist())

    private var heightConstraint: NSLayoutConstraint?

    public override func loadView() {
        view = NSView(frame: NSRect(origin: CGPoint.zero, size: defaultSize))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.model.delegate = self

        let waitlistRootView = WaitlistRootView { newHeight in
            self.updateViewHeight(height: newHeight)
        }

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
    }

    private func updateViewHeight(height: CGFloat) {
        print("DEBUG: New height = \(height)")
        heightConstraint?.constant = height
    }

    static func show(completion: (() -> Void)? = nil) {
        guard let windowController = WindowControllersManager.shared.lastKeyMainWindowController,
              windowController.window?.isKeyWindow == true else {
            return
        }

        let viewController = WaitlistModalViewController(nibName: nil, bundle: nil)
        windowController.mainViewController.beginSheet(viewController) { _ in
            completion?()
        }
    }

}

extension WaitlistModalViewController: WaitlistViewModelDelegate {

    func dismissModal() {
        self.dismiss()
    }

}
