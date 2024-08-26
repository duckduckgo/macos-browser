//
//  DuckPlayerOnboardingViewController.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import SwiftUI
import AppKit

final class DuckPlayerOnboardingViewController: NSViewController {
    var didFinish: () -> Void

    internal init(didFinish: @escaping () -> Void) {
        self.didFinish = didFinish
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var hostingView: NSHostingView<DuckPlayerOnboardingModalView>!
    private lazy var viewModel: DuckPlayerOnboardingViewModel = {
        let viewModel = DuckPlayerOnboardingViewModel()
        viewModel.delegate = self
        return viewModel
    }()

    override func loadView() {
        let consentView = DuckPlayerOnboardingModalView(viewModel: viewModel)
        hostingView = NSHostingView(rootView: consentView)
        self.view = hostingView
    }

    private func handleEnableDuckPlayerActionButton() {
        print("Enabled")
    }

    private func handleNotNowActionButton() {
        didFinish()
    }

    private func handleGotItActionButton() {
        didFinish()
    }
}

extension DuckPlayerOnboardingViewController: DuckPlayerOnboardingViewModelDelegate{
    func duckPlayerOnboardingViewModelDidSelectTurnOn(_ viewModel: DuckPlayerOnboardingViewModel) {
        handleEnableDuckPlayerActionButton()
    }

    func duckPlayerOnboardingViewModelDidSelectNotNow(_ viewModel: DuckPlayerOnboardingViewModel) {
        handleNotNowActionButton()
    }

    func duckPlayerOnboardingViewModelDidSelectGotIt(_ viewModel: DuckPlayerOnboardingViewModel) {
        handleGotItActionButton()
    }
}
