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
import Combine
import Common
import DataBrokerProtection

final class FreemiumDBPPromotionViewCoordinatorTests: XCTestCase {

    private var sut: FreemiumDBPPromotionViewCoordinator!
    private var mockUserStateManager: MockFreemiumDBPUserStateManager!
    private var mockFeature: MockFreemiumDBPFeature!
    private var mockPresenter: MockFreemiumDBPPresenter!
    private let notificationCenter: NotificationCenter = .default
    private var mockPixelHandler: MockFreemiumDBPExperimentPixelHandler!
    private var cancellables: Set<AnyCancellable> = []

    @MainActor
    override func setUpWithError() throws {
        mockUserStateManager = MockFreemiumDBPUserStateManager()
        mockFeature = MockFreemiumDBPFeature()
        mockPresenter = MockFreemiumDBPPresenter()
        mockPixelHandler = MockFreemiumDBPExperimentPixelHandler()

        sut = FreemiumDBPPromotionViewCoordinator(
            freemiumDBPUserStateManager: mockUserStateManager,
            freemiumDBPFeature: mockFeature,
            freemiumDBPPresenter: mockPresenter,
            notificationCenter: notificationCenter,
            freemiumDBPExperimentPixelHandler: mockPixelHandler
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
            freemiumDBPFeature: mockFeature,
            freemiumDBPPresenter: mockPresenter
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
            freemiumDBPFeature: mockFeature,
            freemiumDBPPresenter: mockPresenter
        )

        // Then
        XCTAssertFalse(sut.isHomePagePromotionVisible)
    }

    @MainActor
    func testProceedAction_dismissesPromotion_callsShowFreemium_andFiresPixel() {
        // Given
        mockUserStateManager.didActivate = false

        // When
        let viewModel = sut.viewModel
        viewModel.proceedAction()

        // Then
        XCTAssertTrue(mockUserStateManager.didDismissHomePagePromotion)
        XCTAssertTrue(mockPresenter.didCallShowFreemium)
        XCTAssertEqual(mockPixelHandler.lastFiredEvent, FreemiumDBPExperimentPixel.newTabScanClick)
    }

    @MainActor
    func testCloseAction_dismissesPromotion_andFiresPixel() {
        // When
        let viewModel = sut.viewModel
        viewModel.closeAction()

        // Then
        XCTAssertTrue(mockUserStateManager.didDismissHomePagePromotion)
        XCTAssertEqual(mockPixelHandler.lastFiredEvent, FreemiumDBPExperimentPixel.newTabScanDismiss)
    }

    @MainActor
    func testProceedAction_dismissesResults_callsShowFreemium_andFiresPixel() {
        // Given
        mockUserStateManager.didActivate = false
        mockUserStateManager.firstScanResults = FreemiumDBPMatchResults(matchesCount: 5, brokerCount: 2)

        // When
        let viewModel = sut.viewModel
        viewModel.proceedAction()

        // Then
        XCTAssertTrue(mockUserStateManager.didDismissHomePagePromotion)
        XCTAssertTrue(mockPresenter.didCallShowFreemium)
        XCTAssertEqual(mockPixelHandler.lastFiredEvent, FreemiumDBPExperimentPixel.newTabResultsClick)
    }

    @MainActor
    func testCloseAction_dismissesResults_andFiresPixel() {
        // Given
        mockUserStateManager.firstScanResults = FreemiumDBPMatchResults(matchesCount: 5, brokerCount: 2)

        // When
        let viewModel = sut.viewModel
        viewModel.closeAction()

        // Then
        XCTAssertTrue(mockUserStateManager.didDismissHomePagePromotion)
        XCTAssertEqual(mockPixelHandler.lastFiredEvent, FreemiumDBPExperimentPixel.newTabResultsDismiss)
    }

    @MainActor
    func testProceedAction_dismissesNoResults_callsShowFreemium_andFiresPixel() {
        // Given
        mockUserStateManager.didActivate = false
        mockUserStateManager.firstScanResults = FreemiumDBPMatchResults(matchesCount: 0, brokerCount: 0)

        // When
        let viewModel = sut.viewModel
        viewModel.proceedAction()

        // Then
        XCTAssertTrue(mockUserStateManager.didDismissHomePagePromotion)
        XCTAssertTrue(mockPresenter.didCallShowFreemium)
        XCTAssertEqual(mockPixelHandler.lastFiredEvent, FreemiumDBPExperimentPixel.newTabNoResultsClick)
    }

    @MainActor
    func testCloseAction_dismissesNoResults_andFiresPixel() {
        // Given
        mockUserStateManager.firstScanResults = FreemiumDBPMatchResults(matchesCount: 0, brokerCount: 0)

        // When
        let viewModel = sut.viewModel
        viewModel.closeAction()

        // Then
        XCTAssertTrue(mockUserStateManager.didDismissHomePagePromotion)
        XCTAssertEqual(mockPixelHandler.lastFiredEvent, FreemiumDBPExperimentPixel.newTabNoResultsDismiss)
    }

    @MainActor
    func testViewModel_whenResultsExist_withMatches() {
        // Given
        mockUserStateManager.firstScanResults = FreemiumDBPMatchResults(matchesCount: 5, brokerCount: 2)

        // When
        let viewModel = sut.viewModel

        // Then
        XCTAssertEqual(viewModel.description, UserText.homePagePromotionFreemiumDBPPostScanEngagementResultPluralDescription(resultCount: 5, brokerCount: 2))
    }

    @MainActor
    func testViewModel_whenNoResultsExist() {
        // Given
        mockUserStateManager.firstScanResults = nil

        // When
        let viewModel = sut.viewModel

        // Then
        XCTAssertEqual(viewModel.description, UserText.homePagePromotionFreemiumDBPDescription)
    }

    func testNotificationObservation_updatesPromotionVisibility() {
        // When
        notificationCenter.post(name: .freemiumDBPResultPollingComplete, object: nil)

        // Then
        XCTAssertFalse(mockUserStateManager.didDismissHomePagePromotion)

        // When
        notificationCenter.post(name: .freemiumDBPEntryPointActivated, object: nil)

        // Then
        XCTAssertFalse(mockUserStateManager.didDismissHomePagePromotion)
    }

    @MainActor
    func testHomePageBecomesVisible_whenFeatureBecomesAvailable_andDidDismissFalse() {
        // Given
        mockUserStateManager.didDismissHomePagePromotion = false
        mockFeature.featureAvailable = false
        let expectation = XCTestExpectation(description: "isHomePagePromotionVisible becomes true")
        sut = FreemiumDBPPromotionViewCoordinator(
            freemiumDBPUserStateManager: mockUserStateManager,
            freemiumDBPFeature: mockFeature,
            freemiumDBPPresenter: mockPresenter
        )
        XCTAssertFalse(sut.isHomePagePromotionVisible)

        // When
        mockFeature.isAvailableSubject.send(true)

        sut.$isHomePagePromotionVisible
            .sink { isVisible in
                if isVisible {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)

        // Then
        XCTAssertTrue(sut.isHomePagePromotionVisible)
    }

    @MainActor
    func testHomePageBecomesInVisible_whenFeatureBecomesUnAvailable_andDidDismissFalse() {
        // Given
        mockUserStateManager.didDismissHomePagePromotion = false
        mockFeature.featureAvailable = true
        let expectation = XCTestExpectation(description: "isHomePagePromotionVisible becomes true")
        sut = FreemiumDBPPromotionViewCoordinator(
            freemiumDBPUserStateManager: mockUserStateManager,
            freemiumDBPFeature: mockFeature,
            freemiumDBPPresenter: mockPresenter
        )
        XCTAssertTrue(sut.isHomePagePromotionVisible)

        // When
        mockFeature.isAvailableSubject.send(false)

        sut.$isHomePagePromotionVisible
            .sink { isVisible in
                if !isVisible {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)

        // Then
        XCTAssertFalse(sut.isHomePagePromotionVisible)
    }

    @MainActor
    func testHomePageDoesNotBecomeVisible_whenFeatureBecomesAvailable_andDidDismissTrue() {
        // Given
        mockUserStateManager.didDismissHomePagePromotion = true
        mockFeature.featureAvailable = false
        let expectation = XCTestExpectation(description: "isHomePagePromotionVisible becomes true")
        sut = FreemiumDBPPromotionViewCoordinator(
            freemiumDBPUserStateManager: mockUserStateManager,
            freemiumDBPFeature: mockFeature,
            freemiumDBPPresenter: mockPresenter
        )
        XCTAssertFalse(sut.isHomePagePromotionVisible)

        // When
        mockFeature.isAvailableSubject.send(true)

        sut.$isHomePagePromotionVisible
            .sink { isVisible in
                if !isVisible {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)

        // Then
        XCTAssertFalse(sut.isHomePagePromotionVisible)
    }

    @MainActor
    func testHomePageDoesNotBecomeVisible_whenFeatureBecomesUnAvailable_andDidDismissTrue() {
        // Given
        mockUserStateManager.didDismissHomePagePromotion = true
        mockFeature.featureAvailable = true
        let expectation = XCTestExpectation(description: "isHomePagePromotionVisible becomes true")
        sut = FreemiumDBPPromotionViewCoordinator(
            freemiumDBPUserStateManager: mockUserStateManager,
            freemiumDBPFeature: mockFeature,
            freemiumDBPPresenter: mockPresenter
        )
        XCTAssertFalse(sut.isHomePagePromotionVisible)

        // When
        mockFeature.isAvailableSubject.send(false)

        sut.$isHomePagePromotionVisible
            .sink { isVisible in
                if !isVisible {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)

        // Then
        XCTAssertFalse(sut.isHomePagePromotionVisible)
    }
}

class MockFreemiumDBPExperimentPixelHandler: EventMapping<FreemiumDBPExperimentPixel> {

    var lastFiredEvent: FreemiumDBPExperimentPixel?
    var lastPassedParameters: [String: String]?

    init() {
        var mockMapping: Mapping! = nil

        super.init(mapping: { event, error, params, onComplete in
            // Call the closure after initialization
            mockMapping(event, error, params, onComplete)
        })

        // Now, set the real closure that captures self and stores parameters.
        mockMapping = { [weak self] (event, error, params, onComplete) in
            // Capture the inputs when fire is called
            self?.lastFiredEvent = event
            self?.lastPassedParameters = params
        }
    }

    func resetCapturedData() {
        lastFiredEvent = nil
        lastPassedParameters = nil
    }
}
