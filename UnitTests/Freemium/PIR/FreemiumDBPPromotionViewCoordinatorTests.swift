//
//  FreemiumDBPPromotionViewCoordinatorTests.swift
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

import XCTest
import Freemium
@testable import DuckDuckGo_Privacy_Browser

final class FreemiumDBPPromotionViewCoordinatorTests: XCTestCase {

    private var sut: FreemiumDBPPromotionViewCoordinator!
    private var mockUserStateManager: MockFreemiumPIRUserStateManager!
    private var mockFeature: MockFreemiumPIRFeature!
    private var mockPresenter: MockFreemiumPIRPresenter!

    @MainActor
    override func setUpWithError() throws {
        mockUserStateManager = MockFreemiumPIRUserStateManager()
        mockFeature = MockFreemiumPIRFeature()
        mockPresenter = MockFreemiumPIRPresenter()

        sut = FreemiumDBPPromotionViewCoordinator(
            freemiumDBPUserStateManager: mockUserStateManager,
            freemiumPIRFeature: mockFeature,
            freemiumPIRPresenter: mockPresenter
        )
    }

    override func tearDownWithError() throws {
        sut = nil
        mockUserStateManager = nil
        mockFeature = nil
        mockPresenter = nil
    }

    @MainActor
    func testInitialPromotionVisibility_whenFeatureIsAvailable_andNotDismissed() {
        // Given
        mockUserStateManager.didDismissHomePagePromotion = false
        mockFeature.featureAvailable = true

        // When
        sut = FreemiumDBPPromotionViewCoordinator(
            freemiumDBPUserStateManager: mockUserStateManager,
            freemiumPIRFeature: mockFeature,
            freemiumPIRPresenter: mockPresenter
        )

        // Then
        XCTAssertTrue(sut.isHomePagePromotionVisible)
    }

    @MainActor
    func testInitialPromotionVisibility_whenPromotionDismissed() {
        // Given
        mockUserStateManager.didDismissHomePagePromotion = true
        mockFeature.featureAvailable = true

        // When
        sut = FreemiumDBPPromotionViewCoordinator(
            freemiumDBPUserStateManager: mockUserStateManager,
            freemiumPIRFeature: mockFeature,
            freemiumPIRPresenter: mockPresenter
        )

        // Then
        XCTAssertFalse(sut.isHomePagePromotionVisible)
    }

    @MainActor
    func testProceedAction_marksUserAsOnboarded_andDismissesPromotion() {
        // Given
        mockUserStateManager.didOnboard = false

        // When
        let viewModel = sut.viewModel
        viewModel.proceedAction()

        // Then
        XCTAssertTrue(mockUserStateManager.didOnboard)
        XCTAssertTrue(mockUserStateManager.didDismissHomePagePromotion)
        XCTAssertTrue(mockPresenter.didCallShowFreemium)
    }

    @MainActor
    func testCloseAction_dismissesPromotion() {
        // When
        let viewModel = sut.viewModel
        viewModel.closeAction()

        // Then
        XCTAssertTrue(mockUserStateManager.didDismissHomePagePromotion)
    }

    @MainActor
    func testViewModel_whenResultsExist_withMatches() {
        // Given
        mockUserStateManager.firstScanResults = FreemiumDBPMatchResults(matchesCount: 5, brokerCount: 2)

        // When
        let viewModel = sut.viewModel

        // Then
        XCTAssertEqual(viewModel.title, UserText.homePagePromotionFreemiumPIRPostScanEngagementResultsTitle)
        XCTAssertEqual(viewModel.subtitle, UserText.homePagePromotionFreemiumPIRPostScanEngagementResultPluralSubtitle(resultCount: 5, brokerCount: 2))
    }

    @MainActor
    func testViewModel_whenNoResultsExist() {
        // Given
        mockUserStateManager.firstScanResults = nil

        // When
        let viewModel = sut.viewModel

        // Then
        XCTAssertEqual(viewModel.subtitle, UserText.homePagePromotionFreemiumPIRSubtitle)
    }

    func testNotificationObservation_updatesPromotionVisibility() {
        // When
        NotificationCenter.default.post(name: .freemiumDBPResultPollingComplete, object: nil)

        // Then
        XCTAssertFalse(mockUserStateManager.didDismissHomePagePromotion)

        // When
        NotificationCenter.default.post(name: .freemiumDBPEntryPointActivated, object: nil)

        // Then
        XCTAssertFalse(mockUserStateManager.didDismissHomePagePromotion)
    }
}
