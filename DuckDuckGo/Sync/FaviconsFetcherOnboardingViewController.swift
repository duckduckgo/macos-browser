//
//  FaviconsFetcherOnboardingViewController.swift
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
import SyncUI_macOS

final class FaviconsFetcherOnboardingViewController: NSViewController {

    init(_ viewModel: FaviconsFetcherOnboardingViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private weak var viewModel: FaviconsFetcherOnboardingViewModel?

    override func loadView() {
        guard let viewModel else {
            assertionFailure("Sync FaviconsFetcherOnboardingViewModel was deallocated")
            view = NSView()
            return
        }
        let onboardingDialog = FaviconsFetcherOnboardingView(model: viewModel)
        view = NSHostingView(rootView: onboardingDialog)
    }

}
