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
import SwiftUI

final class ConnectBitwardenViewController: NSViewController {
    
    private let viewSize = CGSize(width: 550, height: 300)

    private lazy var connectBitwardenView: NSHostingView<ConnectBitwardenView> = {
        return NSHostingView(rootView: ConnectBitwardenView())
    }()
    
    public override func loadView() {
        view = NSView(frame: NSRect(origin: CGPoint.zero, size: viewSize))
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(connectBitwardenView)

        setupConstraints()
    }

    private func setupConstraints() {
        connectBitwardenView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            connectBitwardenView.heightAnchor.constraint(equalToConstant: viewSize.height),
            connectBitwardenView.widthAnchor.constraint(equalToConstant: viewSize.width),
            connectBitwardenView.topAnchor.constraint(equalTo: view.topAnchor),
            connectBitwardenView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            connectBitwardenView.leftAnchor.constraint(equalTo: view.leftAnchor),
            connectBitwardenView.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])
    }
    
}
