//
//  VPNFeedbackFormViewModelTests.swift
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

#if NETWORK_PROTECTION

final class VPNFeedbackFormViewModelTests: XCTestCase {

    func testWhenCancelActionIsReceived_ThenViewModelSendsCancelActionToDelegate() throws {
        let collector = MockVPNMetadataCollector()
        let sender = MockVPNFeedbackSender()
        let delegate = MockVPNFeedbackFormViewModelDelegate()
        let viewModel = VPNFeedbackFormViewModel(metadataCollector: collector, feedbackSender: sender)
        viewModel.delegate = delegate

        XCTAssertFalse(delegate.receivedDismissedViewCallback)
        viewModel.process(action: .cancel)
        XCTAssertTrue(delegate.receivedDismissedViewCallback)
    }

    func testWhenCancelActionIsReceived_ThenViewModelSendsCancelActionToDelegate() throws {
        let collector = MockVPNMetadataCollector()
        let sender = MockVPNFeedbackSender()
        let delegate = MockVPNFeedbackFormViewModelDelegate()
        let viewModel = VPNFeedbackFormViewModel(metadataCollector: collector, feedbackSender: sender)
        viewModel.delegate = delegate

        XCTAssertFalse(delegate.receivedDismissedViewCallback)
        viewModel.process(action: .cancel)
        XCTAssertTrue(delegate.receivedDismissedViewCallback)
    }

}

// MARK: - Mocks

private class MockVPNMetadataCollector: VPNMetadataCollector {

    var collectedMetadata: Bool = false

    func collectMetadata() async -> VPNMetadata {
        self.collectedMetadata = true

        let appInfo = VPNMetadata.AppInfo(appVersion: "1.2.3", lastVersionRun: "1.2.3", isInternalUser: false)
        let deviceInfo = VPNMetadata.DeviceInfo(osVersion: "14.0.0", buildFlavor: "dmg", lowPowerModeEnabled: false)
        let networkInfo = VPNMetadata.NetworkInfo(currentPath: "path")

        let vpnState = VPNMetadata.VPNState(
            onboardingState: "onboarded",
            connectionState: "connected",
            lastErrorMessage: "none",
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
            selectedEnvironment: "production"
        )

        let loginItemState = VPNMetadata.LoginItemState(
            vpnMenuState: "enabled",
            notificationsAgentState: "enabled"
        )

        return VPNMetadata(
            appInfo: appInfo,
            deviceInfo: deviceInfo,
            networkInfo: networkInfo,
            vpnState: vpnState,
            vpnSettingsState: vpnSettingsState,
            loginItemState: loginItemState
        )
    }

}

private class MockVPNFeedbackSender: VPNFeedbackSender {

    var throwErrorWhenSending: Bool = false
    var sentMetadata: Bool = false

    func send(metadata: VPNMetadata, category: VPNFeedbackCategory, userText: String) async throws {
        self.sentMetadata = true
    }

}

private class MockVPNFeedbackFormViewModelDelegate: VPNFeedbackFormViewModelDelegate {

    var receivedDismissedViewCallback: Bool = false

    func vpnFeedbackViewModelDismissedView(_ viewModel: VPNFeedbackFormViewModel) {
        receivedDismissedViewCallback = true
    }

}

#endif
