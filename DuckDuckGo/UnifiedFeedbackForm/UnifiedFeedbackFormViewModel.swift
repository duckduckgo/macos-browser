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
import Networking
import Subscription

protocol UnifiedFeedbackFormViewModelDelegate: AnyObject {
    func feedbackViewModelDismissedView(_ viewModel: UnifiedFeedbackFormViewModel)
}

final class UnifiedFeedbackFormViewModel: ObservableObject {
    private static let feedbackEndpoint = URL(string: "https://subscriptions.duckduckgo.com/api/feedback")!
    private static let platform = "macos"

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

    enum Error: String, Swift.Error {
        case missingAccessToken
        case invalidResponse
    }

    enum ViewAction {
        case cancel
        case submit
        case faqClick
        case reportShow
        case reportSubmitShow
        case reportFAQClick
    }

    struct Payload: Codable {
        let userEmail: String
        let feedbackSource: String
        let platform: String
        let problemCategory: String

        let feedbackText: String
        let problemSubCategory: String
        let customMetadata: String

        func toData() -> Data? {
            try? JSONEncoder().encode(self)
        }
    }

    struct Response: Codable {
        let message: String?
        let error: String?
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
            let defaultCategory: UnifiedFeedbackCategory
            switch source {
            case .ppro: defaultCategory = .subscription
            case .vpn: defaultCategory = .vpn
            case .pir: defaultCategory = .pir
            case .itr: defaultCategory = .itr
            default: defaultCategory = .prompt
            }
            selectedCategory = defaultCategory.rawValue
            updateSubmitShowStatus()
        }
    }
    @Published var selectedCategory: String = UnifiedFeedbackCategory.prompt.rawValue {
        didSet {
            selectedSubcategory = selectedSubcategoryPrompt
            updateSubmitShowStatus()
        }
    }
    @Published var selectedSubcategory = "" {
        didSet {
            updateSubmitShowStatus()
        }
    }

    @Published var userEmail = "" {
        didSet {
            updateSubmitButtonStatus()
        }
    }

    private var selectedSubcategoryPrompt: String {
        switch UnifiedFeedbackCategory(rawValue: selectedCategory) {
        case .selectFeature, nil: return ""
        case .subscription: return PrivacyProFeedbackSubcategory.prompt.rawValue
        case .vpn: return VPNFeedbackSubcategory.prompt.rawValue
        case .pir: return PIRFeedbackSubcategory.prompt.rawValue
        case .itr: return ITRFeedbackSubcategory.prompt.rawValue
        }
    }

    @Published var needsSubmitShowReport = false

    var usesCompactForm: Bool {
        switch UnifiedFeedbackReportType(rawValue: selectedReportType) {
        case .reportIssue:
            return false
        default:
            return true
        }
    }

    weak var delegate: UnifiedFeedbackFormViewModelDelegate?

    private let accountManager: any AccountManager
    private let apiService: any Networking.APIService
    private let vpnMetadataCollector: any UnifiedMetadataCollector
    private let defaultMetadataCollector: any UnifiedMetadataCollector
    private let feedbackSender: any UnifiedFeedbackSender

    let source: UnifiedFeedbackSource
    private(set) var availableCategories: [UnifiedFeedbackCategory] = [.selectFeature, .subscription]

    init(subscriptionManager: any SubscriptionManager,
         apiService: any Networking.APIService,
         vpnMetadataCollector: any UnifiedMetadataCollector,
         defaultMetadataCollector: any UnifiedMetadataCollector = EmptyMetadataCollector(),
         feedbackSender: any UnifiedFeedbackSender = DefaultFeedbackSender(),
         source: UnifiedFeedbackSource = .default) {
        self.viewState = .feedbackPending

        self.accountManager = subscriptionManager.accountManager
        self.apiService = apiService
        self.vpnMetadataCollector = vpnMetadataCollector
        self.defaultMetadataCollector = defaultMetadataCollector
        self.feedbackSender = feedbackSender
        self.source = source

        Task {
            let features = await subscriptionManager.currentSubscriptionFeatures()

            if features.contains(.networkProtection) {
                availableCategories.append(.vpn)
            }
            if features.contains(.dataBrokerProtection) {
                availableCategories.append(.pir)
            }
            if features.contains(.identityTheftRestoration) || features.contains(.identityTheftRestorationGlobal) {
                availableCategories.append(.itr)
            }
        }
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
        case .faqClick:
            await openFAQ()
        case .reportShow:
            feedbackSender.sendFormShowPixel()
        case .reportSubmitShow:
            feedbackSender.sendSubmitScreenShowPixel(source: source,
                                                     reportType: selectedReportType,
                                                     category: selectedCategory,
                                                     subcategory: selectedSubcategory)
            needsSubmitShowReport = false
        case .reportFAQClick:
            feedbackSender.sendSubmitScreenFAQClickPixel(source: source,
                                                         reportType: selectedReportType,
                                                         category: selectedCategory,
                                                         subcategory: selectedSubcategory)
        }
    }

    private func openFAQ() async {
        guard !selectedReportType.isEmpty, UnifiedFeedbackReportType(rawValue: selectedReportType) == .reportIssue,
              !selectedCategory.isEmpty, let category = UnifiedFeedbackCategory(rawValue: selectedCategory),
              !selectedSubcategory.isEmpty else {
            return
        }

        let url: URL? = {
            switch category {
            case .selectFeature: return nil
            case .subscription: return PrivacyProFeedbackSubcategory(rawValue: selectedSubcategory)?.url
            case .vpn: return VPNFeedbackSubcategory(rawValue: selectedSubcategory)?.url
            case .pir: return PIRFeedbackSubcategory(rawValue: selectedSubcategory)?.url
            case .itr: return ITRFeedbackSubcategory(rawValue: selectedSubcategory)?.url
            }
        }()

        if let url {
            NSWorkspace.shared.open(url)
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
    }

    private func reportProblem() async throws {
        switch UnifiedFeedbackCategory(rawValue: selectedCategory) {
        case .vpn:
            let metadata = await vpnMetadataCollector.collectMetadata()
            try await submitIssue(metadata: metadata)
            try await feedbackSender.sendReportIssuePixel(source: source,
                                                          category: selectedCategory,
                                                          subcategory: selectedSubcategory,
                                                          description: feedbackFormText,
                                                          metadata: metadata as? VPNMetadata)
        default:
            let metadata = await defaultMetadataCollector.collectMetadata()
            try await submitIssue(metadata: metadata)
            try await feedbackSender.sendReportIssuePixel(source: source,
                                                          category: selectedCategory,
                                                          subcategory: selectedSubcategory,
                                                          description: feedbackFormText,
                                                          metadata: metadata as? EmptyFeedbackMetadata)
        }
    }

    private func submitIssue(metadata: UnifiedFeedbackMetadata?) async throws {
        guard !userEmail.isEmpty else { return }

        guard let accessToken = accountManager.accessToken else {
            throw Error.missingAccessToken
        }

        let payload = Payload(userEmail: userEmail,
                              feedbackSource: source.rawValue,
                              platform: Self.platform,
                              problemCategory: selectedCategory,
                              feedbackText: feedbackFormText,
                              problemSubCategory: selectedSubcategory,
                              customMetadata: metadata?.toString() ?? "")
        let headers = APIRequestV2.HeadersV2(additionalHeaders: [HTTPHeaderKey.authorization: "Bearer \(accessToken)"])
        guard let request = APIRequestV2(url: Self.feedbackEndpoint, method: .post, headers: headers, body: payload.toData()) else {
            assertionFailure("Invalid request")
            return
        }

        let response: Response = try await apiService.fetch(request: request).decodeBody()
        if let error = response.error, !error.isEmpty {
            throw Error.invalidResponse
        }
    }

    private func updateSubmitButtonStatus() {
        self.submitButtonEnabled = viewState.canSubmit && !feedbackFormText.isEmpty && (userEmail.isEmpty || userEmail.isValidEmail)
    }

    private func updateSubmitShowStatus() {
        needsSubmitShowReport = {
            switch UnifiedFeedbackReportType(rawValue: selectedReportType) {
            case .selectReportType, nil:
                return false
            case .requestFeature, .general:
                return true
            case .reportIssue:
                return selectedCategory != UnifiedFeedbackCategory.prompt.rawValue && selectedSubcategory != selectedSubcategoryPrompt
            }
        }()
    }
}

private extension String {
    var isValidEmail: Bool {
        guard let regex = try? NSRegularExpression(pattern: #"[^\s]+@[^\s]+\.[^\s]+"#) else { return false }
        return matches(regex)
    }
}
