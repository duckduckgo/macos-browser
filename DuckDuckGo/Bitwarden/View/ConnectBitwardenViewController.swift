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
    private let viewModel = ConnectBitwardenViewModel(bitwardenInstallationService: LocalBitwardenInstallationManager())
    
    public override func loadView() {
        view = NSView(frame: NSRect(origin: CGPoint.zero, size: viewSize))
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        
        let connectBitwardenView = ConnectBitwardenView() .environmentObject(self.viewModel)
        let hostingView = NSHostingView(rootView: connectBitwardenView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(hostingView)
        
        NSLayoutConstraint.activate([
            hostingView.heightAnchor.constraint(equalToConstant: viewSize.height),
            hostingView.widthAnchor.constraint(equalToConstant: viewSize.width),
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingView.leftAnchor.constraint(equalTo: view.leftAnchor),
            hostingView.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])
    }
    
}

extension ConnectBitwardenViewController: ConnectBitwardenViewModelDelegate {
    
    func connectBitwardenViewModelDismissedView(_ viewModel: ConnectBitwardenViewModel) {
        dismiss()
    }
    
}
