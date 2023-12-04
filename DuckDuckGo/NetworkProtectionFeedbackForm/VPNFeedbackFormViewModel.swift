//
//  VPNFeedbackFormViewModel.swift
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

#if NETWORK_PROTECTION

import Foundation
import Combine
import SwiftUI

protocol VPNFeedbackFormViewModelDelegate: AnyObject {
    func vpnFeedbackViewModelDismissedView(_ viewModel: VPNFeedbackFormViewModel)
}

final class VPNFeedbackFormViewModel: ObservableObject {

    enum ViewState {
        case feedbackPending
        case feedbackSending
        case feedbackSendingFailed
        case feedbackSent
    }

    enum ViewAction {
        case cancel
        case submit
    }

    @Published var viewState: ViewState {
        didSet {
            updateSubmitButtonStatus()
        }
    }

    @Published var feedbackFormText: String = "" {
        didSet {
            updateSubmitButtonStatus()
        }
    }

    @Published private(set) var submitButtonEnabled: Bool = false
    @Published var selectedFeedbackCategory: VPNFeedbackCategory

    weak var delegate: VPNFeedbackFormViewModelDelegate?

    private let metadataCollector: VPNMetadataCollector
    private let feedbackSender: VPNFeedbackSender

    init(metadataCollector: VPNMetadataCollector = DefaultVPNMetadataCollector(), feedbackSender: VPNFeedbackSender = DefaultVPNFeedbackSender()) {
        self.viewState = .feedbackPending
        self.selectedFeedbackCategory = .landingPage

        self.metadataCollector = metadataCollector
        self.feedbackSender = feedbackSender
    }

    func process(action: ViewAction) {
        switch action {
        case .cancel:
            delegate?.vpnFeedbackViewModelDismissedView(self)
        case .submit:
            self.viewState = .feedbackSending

            Task { @MainActor in
                do {
                    let metadata = await self.metadataCollector.collectMetadata()
                    try await self.feedbackSender.send(metadata: metadata, category: selectedFeedbackCategory, userText: feedbackFormText)
                    self.viewState = .feedbackSent
                } catch {
                    self.viewState = .feedbackSendingFailed
                }
            }
        }
    }

    private func updateSubmitButtonStatus() {
        self.submitButtonEnabled = (viewState == .feedbackPending) && !feedbackFormText.isEmpty
    }

}

#endif
