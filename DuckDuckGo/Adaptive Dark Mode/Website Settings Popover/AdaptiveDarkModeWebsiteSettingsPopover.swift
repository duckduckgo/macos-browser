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
import Combine

protocol AdaptiveDarkModeWebsiteSettingsPopoverDelegate: AnyObject {
    func adaptiveDarkModeWebsiteSettingsPopover(_ popover: AdaptiveDarkModeWebsiteSettingsPopover, didChangeStatus enabled: Bool)
}

final class AdaptiveDarkModeWebsiteSettingsPopover: NSPopover {
    private var statusCancellables = Set<AnyCancellable>()
    weak var statusDelegate: AdaptiveDarkModeWebsiteSettingsPopoverDelegate?
    
    override init() {
        super.init()
        self.behavior = .semitransient
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    func preparePopoverWithURL(_ url: URL) {
        let domain = url.host?.dropWWW() ?? ""
        let isDarkModeEnabled = !DarkModeSettingsStore.shared.isDomainOnExceptionList(domain: domain)
        
        let viewModel = AdaptiveDarkModeWebsiteSettingsViewModel(currentDomain: domain, isEnabled: isDarkModeEnabled)
        
        viewModel.$isDarkModeEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self = self else { return }
                self.statusDelegate?.adaptiveDarkModeWebsiteSettingsPopover(self, didChangeStatus: enabled)
            }.store(in: &statusCancellables)
        
        let controller = AdaptiveDarkModeWebsiteSettingsViewController(viewModel: viewModel)
        contentViewController = controller
    }
}

final class AdaptiveDarkModeWebsiteSettingsViewController: NSViewController {
    private let viewModel: AdaptiveDarkModeWebsiteSettingsViewModel
    
    init(viewModel: AdaptiveDarkModeWebsiteSettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let hostingView = NSHostingView(rootView: AdaptiveDarkModeWebsiteSettingsView(viewModel: viewModel))
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 105)
        view = hostingView
    }
}
