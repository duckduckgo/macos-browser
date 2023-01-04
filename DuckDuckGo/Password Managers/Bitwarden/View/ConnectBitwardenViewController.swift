//
//  ConnectBitwardenViewController.swift
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
import Combine
import SwiftUI

final class ConnectBitwardenViewController: NSViewController {

    private let defaultSize = CGSize(width: 550, height: 280)
    private let viewModel = ConnectBitwardenViewModel(bitwardenManager: BWManager.shared)

    var setupFlowCancellationHandler: (() -> Void)?

    private var heightConstraint: NSLayoutConstraint?

    public override func loadView() {
        view = NSView(frame: NSRect(origin: CGPoint.zero, size: defaultSize))
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self

        let connectBitwardenView = ConnectBitwardenView { newHeight in
            self.updateViewHeight(height: newHeight)
        }

        let hostingView = NSHostingView(rootView: connectBitwardenView.environmentObject(self.viewModel))
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
        heightConstraint?.constant = height
    }

}

extension ConnectBitwardenViewController: ConnectBitwardenViewModelDelegate {

    func connectBitwardenViewModelDismissedView(_ viewModel: ConnectBitwardenViewModel, canceled: Bool) {
        if canceled {
            setupFlowCancellationHandler?()
        }

        dismiss()
    }

}
