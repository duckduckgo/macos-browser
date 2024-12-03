//
//  UnifiedFeedbackFormViewController.swift
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

import Foundation
import AppKit
import SwiftUI
import Combine
import PixelKit
import Subscription
import Networking

final class UnifiedFeedbackFormViewController: NSViewController {
    // Using a dynamic height in the form was causing layout problems and couldn't be completed in time for the release that needed this form.
    // As a temporary measure, the heights of each form state are hardcoded.
    // This should be cleaned up later, and eventually use the `sizingOptions` property of NSHostingController.
    enum Constants {
        static let landingPageHeight = 260.0
        static let feedbackFormMiniHeight = 350.0
        static let feedbackFormCompactHeight = 430.0
        static let feedbackFormHeight = 740.0
        static let feedbackSentHeight = 350.0
    }

    private let defaultSize = CGSize(width: 480, height: Constants.landingPageHeight)

    private let feedbackSender: UnifiedFeedbackSender
    private let viewModel: UnifiedFeedbackFormViewModel

    private var heightConstraint: NSLayoutConstraint?
    private var cancellables = Set<AnyCancellable>()

    init(feedbackSender: UnifiedFeedbackSender = DefaultFeedbackSender(),
         source: UnifiedFeedbackSource = .default) {
        self.feedbackSender = feedbackSender
        self.viewModel = UnifiedFeedbackFormViewModel(subscriptionManager: Application.appDelegate.subscriptionManager,
                                                      apiService: DefaultAPIService(),
                                                      vpnMetadataCollector: DefaultVPNMetadataCollector(accountManager: Application.appDelegate.subscriptionManager.accountManager),
                                                      feedbackSender: feedbackSender,
                                                      source: source)

        super.init(nibName: nil, bundle: nil)
        self.viewModel.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(origin: CGPoint.zero, size: defaultSize))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let feedbackFormView = UnifiedFeedbackFormView()
        let hostingView = NSHostingView(rootView: feedbackFormView.environmentObject(self.viewModel))
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

        subscribeToViewModelChanges()
    }

    func subscribeToViewModelChanges() {
        viewModel.$viewState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateViewHeight()
            }
            .store(in: &cancellables)

        Publishers.MergeMany(
            viewModel.$selectedReportType,
            viewModel.$selectedCategory,
            viewModel.$selectedSubcategory
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.updateViewHeight()
        }
        .store(in: &cancellables)
    }

    private func updateViewHeight() {
        switch viewModel.viewState {
        case .feedbackPending:
            if UnifiedFeedbackReportType(rawValue: viewModel.selectedReportType) == .prompt {
                heightConstraint?.constant = Constants.landingPageHeight
            } else if UnifiedFeedbackReportType(rawValue: viewModel.selectedReportType) == .reportIssue,
                      UnifiedFeedbackCategory(rawValue: viewModel.selectedCategory) == .prompt ||
                      viewModel.selectedSubcategory == PrivacyProFeedbackSubcategory.prompt.rawValue {
                heightConstraint?.constant = Constants.feedbackFormMiniHeight
            } else {
                heightConstraint?.constant = viewModel.usesCompactForm ? Constants.feedbackFormCompactHeight : Constants.feedbackFormHeight
            }
        case .feedbackSending:
            heightConstraint?.constant = viewModel.usesCompactForm ? Constants.feedbackFormCompactHeight : Constants.feedbackFormHeight
        case .feedbackSent:
            heightConstraint?.constant = Constants.feedbackSentHeight
        case .feedbackSendingFailed:
            heightConstraint?.constant = (viewModel.usesCompactForm ? Constants.feedbackFormCompactHeight : Constants.feedbackFormHeight) + 20.0
        }
    }

}

extension UnifiedFeedbackFormViewController: UnifiedFeedbackFormViewModelDelegate {

    func feedbackViewModelDismissedView(_ viewModel: UnifiedFeedbackFormViewModel) {
        dismiss()
    }

}
