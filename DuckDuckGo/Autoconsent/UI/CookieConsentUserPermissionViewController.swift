//
//  CookieConsentUserPermissionViewController.swift
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
import SwiftUI

public final class CookieConsentUserPermissionViewController: NSViewController {
    private let consentView = NSHostingView(rootView: CookieConsentUserPermissionView())
    private let viewSize = CGSize(width: 550, height: 300)
    
    public override func loadView() {
        view = NSView(frame: NSRect(origin: CGPoint.zero, size: viewSize))
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(consentView)
        setupConstraints()
        view.applyDropShadow()
    }
    
    private func setupConstraints() {
        consentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            consentView.heightAnchor.constraint(equalToConstant: viewSize.height),
            consentView.widthAnchor.constraint(equalToConstant: viewSize.width),
            consentView.topAnchor.constraint(equalTo: view.topAnchor),
            consentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            consentView.leftAnchor.constraint(equalTo: view.leftAnchor),
            consentView.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])
    }
}
