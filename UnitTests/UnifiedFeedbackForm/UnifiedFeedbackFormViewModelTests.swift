//
//  UnifiedFeedbackFormViewModelTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class UnifiedFeedbackFormViewModelTests: XCTestCase {

    func testWhenCreatingViewModel_ThenInitialStateIsFeedbackPending() throws {
        let collector = MockVPNMetadataCollector()
        let sender = MockVPNFeedbackSender()
        let viewModel = UnifiedFeedbackFormViewModel(vpnMetadataCollector: collector, feedbackSender: sender)

        XCTAssertEqual(viewModel.viewState, .feedbackPending)
    }

    func testWhenSendingFeedbackSucceeds_ThenFeedbackIsSent() async throws {
        let collector = MockVPNMetadataCollector()
        let sender = MockVPNFeedbackSender()
        let viewModel = UnifiedFeedbackFormViewModel(vpnMetadataCollector: collector, feedbackSender: sender)
        let text = "Some feedback report text"
        viewModel.feedbackFormText = text

        XCTAssertFalse(sender.sentMetadata)
        await viewModel.process(action: .submit)
        XCTAssertTrue(sender.sentMetadata)
        XCTAssertEqual(sender.receivedData!.4, text)
    }

    func testWhenSendingFeedbackFails_ThenFeedbackIsNotSent() async throws {
        let collector = MockVPNMetadataCollector()
        let sender = MockVPNFeedbackSender()
        let viewModel = UnifiedFeedbackFormViewModel(vpnMetadataCollector: collector, feedbackSender: sender)
        let text = "Some feedback report text"
        viewModel.feedbackFormText = text
        sender.throwErrorWhenSending = true

        XCTAssertFalse(sender.sentMetadata)
        await viewModel.process(action: .submit)
        XCTAssertFalse(sender.sentMetadata)
        XCTAssertEqual(viewModel.viewState, .feedbackSendingFailed)
    }

    func testWhenCancelActionIsReceived_ThenViewModelSendsCancelActionToDelegate() async throws {
        let collector = MockVPNMetadataCollector()
        let sender = MockVPNFeedbackSender()
        let delegate = MockVPNFeedbackFormViewModelDelegate()
        let viewModel = UnifiedFeedbackFormViewModel(vpnMetadataCollector: collector, feedbackSender: sender)
        viewModel.delegate = delegate

        XCTAssertFalse(delegate.receivedDismissedViewCallback)
        await viewModel.process(action: .cancel)
        XCTAssertTrue(delegate.receivedDismissedViewCallback)
    }
}

// MARK: - Mocks

private class MockVPNMetadataCollector: UnifiedMetadataCollector {
    var collectedMetadata = false

    func collectMetadata() async -> VPNMetadata? {
        self.collectedMetadata = true

        let appInfo = VPNMetadata.AppInfo(
            appVersion: "1.2.3",
            lastAgentVersionRun: "1.2.3",
            lastExtensionVersionRun: "1.2.3",
            isInternalUser: false,
            isInApplicationsDirectory: true
        )

        let deviceInfo = VPNMetadata.DeviceInfo(
            osVersion: "14.0.0",
            buildFlavor: "dmg",
            lowPowerModeEnabled: false,
            cpuArchitecture: "arm64"
        )

        let networkInfo = VPNMetadata.NetworkInfo(currentPath: "path")

        let vpnState = VPNMetadata.VPNState(
            onboardingState: "onboarded",
            connectionState: "connected",
            lastStartErrorDescription: "none",
            lastTunnelErrorDescription: "none",
            lastKnownFailureDescription: "none",
            connectedServer: "Paoli, PA",
            connectedServerIP: "123.123.123.123"
        )

        let vpnSettingsState = VPNMetadata.VPNSettingsState(
            connectOnLoginEnabled: true,
            includeAllNetworksEnabled: true,
            enforceRoutesEnabled: true,
            excludeLocalNetworksEnabled: true,
            notifyStatusChangesEnabled: true,
            showInMenuBarEnabled: true,
            selectedServer: "server",
            selectedEnvironment: "production",
            customDNS: false
        )

        let loginItemState = VPNMetadata.LoginItemState(
            vpnMenuState: "enabled",
            vpnMenuIsRunning: true,
            notificationsAgentState: "enabled",
            notificationsAgentIsRunning: true
        )

        let privacyProInfo = VPNMetadata.PrivacyProInfo(
            hasPrivacyProAccount: true,
            hasVPNEntitlement: true
        )

        return VPNMetadata(
            appInfo: appInfo,
            deviceInfo: deviceInfo,
            networkInfo: networkInfo,
            vpnState: vpnState,
            vpnSettingsState: vpnSettingsState,
            loginItemState: loginItemState,
            privacyProInfo: privacyProInfo
        )
    }

}

private class MockVPNFeedbackSender: UnifiedFeedbackSender {

    var throwErrorWhenSending: Bool = false
    var sentMetadata: Bool = false

    var receivedData: (VPNMetadata?, String, String?, String?, String?)?

    enum SomeError: Error {
        case error
    }

    func sendFeatureRequestPixel(description: String, source: String) async throws {
        if throwErrorWhenSending {
            throw SomeError.error
        }

        self.sentMetadata = true
        self.receivedData = (nil, source, nil, nil, description)
    }

    func sendGeneralFeedbackPixel(description: String, source: String) async throws {
        if throwErrorWhenSending {
            throw SomeError.error
        }

        self.sentMetadata = true
        self.receivedData = (nil, source, nil, nil, description)
    }

    func sendReportIssuePixel<T: UnifiedFeedbackMetadata>(source: String, category: String, subcategory: String, description: String, metadata: T?) async throws {
        if throwErrorWhenSending {
            throw SomeError.error
        }

        self.sentMetadata = true
        self.receivedData = (metadata as? VPNMetadata, source, category, subcategory, description)
    }

    func sendGeneralScreenShowPixel() async {

    }

    func sendActionsScreenShowPixel(source: String) async {

    }

    func sendCategoryScreenShowPixel(source: String, reportType: String) async {

    }

    func sendSubcategoryScreenShowPixel(source: String, reportType: String, category: String) async {

    }

    func sendSubmitScreenShowPixel(source: String, reportType: String, category: String, subcategory: String) async {

    }
}

private class MockVPNFeedbackFormViewModelDelegate: UnifiedFeedbackFormViewModelDelegate {
    var receivedDismissedViewCallback: Bool = false

    func feedbackViewModelDismissedView(_ viewModel: UnifiedFeedbackFormViewModel) {
        receivedDismissedViewCallback = true
    }

}
