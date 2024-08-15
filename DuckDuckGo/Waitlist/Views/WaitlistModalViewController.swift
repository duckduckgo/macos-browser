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
import UserNotifications

extension Notification.Name {
    static let waitlistModalViewControllerShouldDismiss = Notification.Name(rawValue: "waitlistModalViewControllerShouldDismiss")
}

final class WaitlistModalViewController<ContentView: View>: NSViewController {

    private let defaultSize = CGSize(width: 360, height: 650)
    private let model: WaitlistViewModel
    private let contentView: ContentView
    private var dismissObserver: NSObjectProtocol?

    private var heightConstraint: NSLayoutConstraint?

    init(viewModel: WaitlistViewModel, contentView: ContentView) {
        self.model = viewModel
        self.contentView = contentView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let dismissObserver {
            NotificationCenter.default.removeObserver(dismissObserver)
        }
    }

    public override func loadView() {
        view = NSView(frame: NSRect(origin: CGPoint.zero, size: defaultSize))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.model.delegate = self

        let hostingView = NSHostingView(rootView: contentView.environmentObject(self.model))
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

        dismissObserver = NotificationCenter.default.addObserver(forName: .waitlistModalViewControllerShouldDismiss, object: nil, queue: .main) { [weak self] _ in
            self?.dismissModal()
        }
    }

    private func updateViewHeight(height: CGFloat) {
        heightConstraint?.constant = height
    }
}

extension WaitlistModalViewController: WaitlistViewModelDelegate {

    func dismissModal() {
        self.dismiss()
    }

    func viewHeightChanged(newHeight: CGFloat) {
        updateViewHeight(height: newHeight)
    }

}
