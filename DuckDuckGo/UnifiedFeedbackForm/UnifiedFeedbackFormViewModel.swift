//
//  UnifiedFeedbackFormViewModel.swift
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
import PixelKit

protocol UnifiedFeedbackFormViewModelDelegate: AnyObject {
    func feedbackViewModelDismissedView(_ viewModel: UnifiedFeedbackFormViewModel)
}

final class UnifiedFeedbackFormViewModel: ObservableObject {
    enum Source: String {
        case settings
        case ppro
        case vpn
        case pir
        case itr
        case unknown
    }

    enum ViewState {
        case feedbackPending
        case feedbackSending
        case feedbackSendingFailed
        case feedbackSent

        var canSubmit: Bool {
            switch self {
            case .feedbackPending: return true
            case .feedbackSending: return false
            case .feedbackSendingFailed: return true
            case .feedbackSent: return false
            }
        }
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
    @Published var selectedReportType: String = UnifiedFeedbackReportType.prompt.rawValue {
        didSet {
            selectedCategory = UnifiedFeedbackCategory.prompt.rawValue

            Task {
                await feedbackSender.sendCategoryScreenShowPixel(source: source,
                                                                 reportType: selectedReportType)
            }
        }
    }
    @Published var selectedCategory: String = UnifiedFeedbackCategory.prompt.rawValue {
        didSet {
            switch UnifiedFeedbackCategory(rawValue: selectedCategory) {
            case .selectFeature, nil: selectedSubcategory = ""
            case .subscription: selectedSubcategory = PrivacyProFeedbackSubcategory.prompt.rawValue
            case .vpn: selectedSubcategory = VPNFeedbackSubcategory.prompt.rawValue
            case .pir: selectedSubcategory = PIRFeedbackSubcategory.prompt.rawValue
            case .itr: selectedSubcategory = ITRFeedbackSubcategory.prompt.rawValue
            }

            Task {
                await feedbackSender.sendSubcategoryScreenShowPixel(source: source,
                                                                    reportType: selectedReportType,
                                                                    category: selectedCategory)
            }
        }
    }
    @Published var selectedSubcategory: String = ""

    weak var delegate: UnifiedFeedbackFormViewModelDelegate?

    private let vpnMetadataCollector: any UnifiedMetadataCollector
    private let defaultMetadataCollector: any UnifiedMetadataCollector
    private let feedbackSender: any UnifiedFeedbackSender

    let source: String

    init(vpnMetadataCollector: any UnifiedMetadataCollector,
         defaultMetadatCollector: any UnifiedMetadataCollector = DefaultMetadataCollector(),
         feedbackSender: any UnifiedFeedbackSender = DefaultFeedbackSender(),
         source: Source = .unknown) {
        self.viewState = .feedbackPending

        self.vpnMetadataCollector = vpnMetadataCollector
        self.defaultMetadataCollector = defaultMetadatCollector
        self.feedbackSender = feedbackSender
        self.source = source.rawValue
    }

    @MainActor
    func process(action: ViewAction) async {
        switch action {
        case .cancel:
            delegate?.feedbackViewModelDismissedView(self)
        case .submit:
            self.viewState = .feedbackSending

            do {
                try await sendFeedback()
                self.viewState = .feedbackSent
            } catch {
                self.viewState = .feedbackSendingFailed
            }
        }
    }

    private func sendFeedback() async throws {
        switch UnifiedFeedbackReportType(rawValue: selectedReportType) {
        case .selectReportType, nil:
            return
        case .requestFeature:
            try await feedbackSender.sendFeatureRequestPixel(description: feedbackFormText,
                                                             source: source)
        case .general:
            try await feedbackSender.sendGeneralFeedbackPixel(description: feedbackFormText,
                                                              source: source)
        case .reportIssue:
            try await reportProblem()
        }

        await feedbackSender.sendSubmitScreenShowPixel(source: source,
                                                       reportType: selectedReportType,
                                                       category: selectedCategory,
                                                       subcategory: selectedSubcategory)
    }

    private func reportProblem() async throws {
        switch UnifiedFeedbackCategory(rawValue: selectedCategory) {
        case .vpn:
            let metadata = await vpnMetadataCollector.collectMetadata()
            try await feedbackSender.sendReportIssuePixel(source: source,
                                                          category: selectedCategory,
                                                          subcategory: selectedSubcategory,
                                                          description: feedbackFormText,
                                                          metadata: metadata as? VPNMetadata)
        default:
            let metadata = await defaultMetadataCollector.collectMetadata()
            try await feedbackSender.sendReportIssuePixel(source: source,
                                                          category: selectedCategory,
                                                          subcategory: selectedSubcategory,
                                                          description: feedbackFormText,
                                                          metadata: metadata as? DefaultFeedbackMetadata)
        }
    }

    private func updateSubmitButtonStatus() {
        self.submitButtonEnabled = viewState.canSubmit && !feedbackFormText.isEmpty
    }

}
