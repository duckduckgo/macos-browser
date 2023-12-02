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

import Foundation
import Combine
import SwiftUI

protocol VPNFeedbackFormViewModelDelegate: AnyObject {
    func vpnFeedbackViewModelDismissedView(_ viewModel: VPNFeedbackFormViewModel)
}

final class VPNFeedbackFormViewModel: ObservableObject {

    enum FeedbackCategory: String, CaseIterable {
        case landingPage
        case failsToConnect
        case tooSlow
        case issueWithAppOrWebsite
        case cantConnectToLocalDevice
        case appCrashesOrFreezes
        case featureRequest
        case somethingElse

        var isFeedbackCategory: Bool {
            switch self {
            case .landingPage:
                return false
            case .failsToConnect,
                    .tooSlow,
                    .issueWithAppOrWebsite,
                    .cantConnectToLocalDevice,
                    .appCrashesOrFreezes,
                    .featureRequest,
                    .somethingElse:
                return true
            }
        }

        var displayName: String {
            switch self {
            case .landingPage: return "What's happening?"
            case .failsToConnect: return "VPN fails to connect"
            case .tooSlow: return "VPN is too slow"
            case .issueWithAppOrWebsite: return "Issue with app or website"
            case .cantConnectToLocalDevice: return "Can't connect to local device"
            case .appCrashesOrFreezes: return "App crashes or freezes"
            case .featureRequest: return "Feature request"
            case .somethingElse: return "Something else"
            }
        }
    }

    enum ViewState {
        case feedbackPending
        case feedbackSending
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
    @Published var selectedFeedbackCategory: FeedbackCategory

    weak var delegate: VPNFeedbackFormViewModelDelegate?

    init() {
        self.viewState = .feedbackPending
        self.selectedFeedbackCategory = .landingPage
    }

    func process(action: ViewAction) {
        switch action {
        case .cancel:
            delegate?.vpnFeedbackViewModelDismissedView(self)
        case .submit:
            self.viewState = .feedbackSending

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.viewState = .feedbackSent
            }
        }
    }

    private func updateSubmitButtonStatus() {
        self.submitButtonEnabled = (viewState == .feedbackPending) && !feedbackFormText.isEmpty
    }

}
