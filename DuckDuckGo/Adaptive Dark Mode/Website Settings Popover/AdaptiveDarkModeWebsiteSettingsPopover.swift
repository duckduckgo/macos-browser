//
//  AdaptiveDarkModeWebsiteSettingsPopover.swift
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

final class AdaptiveDarkModeWebsiteSettingsPopover: NSPopover {
    override init() {
        super.init()

        self.behavior = .semitransient
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    func preparePopoverWithURL(_ url: URL) {
        let controller = AdaptiveDarkModeWebsiteSettingsViewController(currentURL: url)
        contentViewController = controller
    }
}

final class AdaptiveDarkModeWebsiteSettingsViewController: NSViewController {
    let currentURL: URL
    
    init(currentURL: URL) {
        self.currentURL = currentURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let viewModel = AdaptiveDarkModeWebsiteSettingsViewModel(currentURL: currentURL)
        let hostingView = NSHostingView(rootView: AdaptiveDarkModeWebsiteSettingsView(viewModel: viewModel))
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 105)
        view = hostingView
    }
}
