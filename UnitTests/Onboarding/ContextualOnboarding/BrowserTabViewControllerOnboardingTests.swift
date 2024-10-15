//
//  BrowserTabViewControllerOnboardingTests.swift
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
import SwiftUI
import Onboarding
import Combine
import BrowserServicesKit
import PrivacyDashboard
@testable import DuckDuckGo_Privacy_Browser

final class BrowserTabViewControllerOnboardingTests: XCTestCase {

    var viewController: BrowserTabViewController!
    var dialogProvider: MockDialogsProvider!
    var factory: CapturingDialogFactory!
    var tab: Tab!
    var cancellables: Set<AnyCancellable> = []
    let expectation = XCTestExpectation()

    @MainActor override func setUpWithError() throws {
        try super.setUpWithError()
        let tabCollectionViewModel = TabCollectionViewModel()
        dialogProvider = MockDialogsProvider()
        factory = CapturingDialogFactory(expectation: expectation)
        tab = Tab()
        tab.setContent(.url(URL.duckDuckGo, credential: nil, source: .appOpenUrl))
        let tabViewModel = TabViewModel(tab: tab)
        viewController = BrowserTabViewController(tabCollectionViewModel: tabCollectionViewModel, onboardingDialogTypeProvider: dialogProvider, onboardingDialogFactory: factory, featureFlagger: MockFeatureFlagger())
        viewController.tabViewModel = tabViewModel
        let window = NSWindow()
        window.contentViewController = viewController
        window.makeKeyAndOrderFront(nil)
    }

    override func tearDownWithError() throws {
        dialogProvider = nil
        factory = nil
        tab = nil
        viewController = nil
        cancellables = []
        try super.tearDownWithError()
    }

    func testWhenNavigationCompletedAndNoDialogTypeThenOnlyWebViewVisible() throws {
        let expectation = self.expectation(description: "Wait for webViewDidFinishNavigationPublisher to emit")
        tab.navigateTo(url: URL(string: "some.url")!)

        tab.webViewDidFinishNavigationPublisher
            .sink {
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 2.0)
        XCTAssertNil(factory.capturedType)
    }

    func testWhenNavigationCompletedAndHighFiveDialogTypeThenCorrectDialogCapturedInFactory() throws {
        dialogProvider.dialog = .highFive
        tab.navigateTo(url: URL(string: "some.url")!)

        wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(factory.capturedType, .highFive)
        XCTAssertIdentical(factory.capturedDelegate, viewController.tabViewModel?.tab)
    }

    func testWhenNavigationCompletedAndSearchDoneDialogTypeThenCorrectDialogCapturedInFactory() throws {
        dialogProvider.dialog = .searchDone(shouldFollowUp: true)
        tab.navigateTo(url: URL(string: "some.url")!)

        wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(factory.capturedType, .searchDone(shouldFollowUp: true))
        XCTAssertIdentical(factory.capturedDelegate, viewController.tabViewModel?.tab)
    }

    func testWhenNavigationCompletedAndTrackersDialogTypeThenCorrectDialogCapturedInFactory() throws {
        dialogProvider.dialog = .trackers(message: NSMutableAttributedString(string: ""), shouldFollowUp: true)
        tab.navigateTo(url: URL(string: "some.url")!)

        wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(factory.capturedType, .trackers(message: NSMutableAttributedString(string: ""), shouldFollowUp: true))
        XCTAssertIdentical(factory.capturedDelegate, viewController.tabViewModel?.tab)
    }

    func testWhenNavigationCompletedAndTryASearchDialogTypeThenCorrectDialogCapturedInFactory() throws {
        dialogProvider.dialog = .tryASearch
        tab.navigateTo(url: URL(string: "some.url")!)

        wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(factory.capturedType, .tryASearch)
        XCTAssertIdentical(factory.capturedDelegate, viewController.tabViewModel?.tab)
    }

    func testWhenNavigationCompletedAndTryASiteDialogTypeThenCorrectDialogCapturedInFactory() throws {
        dialogProvider.dialog = .tryASite
        tab.navigateTo(url: URL(string: "some.url")!)

        wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(factory.capturedType, .tryASite)
        XCTAssertIdentical(factory.capturedDelegate, viewController.tabViewModel?.tab)
    }

    func testWhenNavigationCompletedAndTryFireButtonDialogTypeThenCorrectDialogCapturedInFactory() throws {
        dialogProvider.dialog = .tryFireButton
        tab.navigateTo(url: URL(string: "some.url")!)

        wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(factory.capturedType, .tryFireButton)
        XCTAssertIdentical(factory.capturedDelegate, viewController.tabViewModel?.tab)
    }

    func testWhenNavigationCompletedAndDialogTypeNilThenAskDelegateToRemoveViewHighlights() throws {
        // GIVEN
        let expectation = self.expectation(description: "Wait for webViewDidFinishNavigationPublisher to emit")
        let delegate = BrowserTabViewControllerDelegateMock()
        let url = try XCTUnwrap(URL(string: "some.url"))
        dialogProvider.dialog = nil
        viewController.delegate = delegate
        tab.webViewDidFinishNavigationPublisher
            .sink {
                expectation.fulfill()
            }
            .store(in: &cancellables)
        XCTAssertFalse(delegate.didCallDismissViewHighlight)

        // WHEN
        tab.navigateTo(url: url)

        // THEN
        wait(for: [expectation], timeout: 3.0)
        XCTAssertTrue(delegate.didCallDismissViewHighlight)
    }

    func testWhenNavigationCompletedAndStateIsShowFireButtonThenAskDelegateToHighlightFireButton() throws {
        // GIVEN
        dialogProvider.dialog = .tryFireButton
        let url = try XCTUnwrap(URL(string: "some.url"))
        let delegate = BrowserTabViewControllerDelegateMock()
        viewController.delegate = delegate
        XCTAssertFalse(delegate.didCallHighlightFireButton)

        // WHEN
        tab.navigateTo(url: url)

        // THEN
        wait(for: [expectation], timeout: 3.0)
        XCTAssertTrue(delegate.didCallHighlightFireButton)
    }

    func testWhenNavigationCompletedViewHighlightsAreRemoved() throws {
        // GIVEN
        dialogProvider.dialog = .searchDone(shouldFollowUp: false)
        let url = try XCTUnwrap(URL(string: "some.url"))
        let delegate = BrowserTabViewControllerDelegateMock()
        viewController.delegate = delegate
        XCTAssertFalse(delegate.didCallDismissViewHighlight)

        // WHEN
        tab.navigateTo(url: url)

        // THEN
        wait(for: [expectation], timeout: 3.0)
        XCTAssertTrue(delegate.didCallDismissViewHighlight)
    }

    func testWhenGotItButtonPressedThenAskDelegateToRemoveViewHighlights() throws {
        // GIVEN
        let expectation = self.expectation(description: "Wait for webViewDidFinishNavigationPublisher to emit")
        let delegate = BrowserTabViewControllerDelegateMock()
        let url = try XCTUnwrap(URL(string: "some.url"))
        dialogProvider.dialog = nil
        viewController.delegate = delegate
        tab.webViewDidFinishNavigationPublisher
            .sink {
                expectation.fulfill()
            }
            .store(in: &cancellables)
        tab.navigateTo(url: url)
        XCTAssertFalse(delegate.didCallDismissViewHighlight)
        wait(for: [expectation], timeout: 3.0)

        // WHEN
        factory.performOnGotItPressed()

        // THEN
        XCTAssertTrue(delegate.didCallDismissViewHighlight)
    }

    func testWhenGotItButtonPressedAndStateIsShowFireButtonThenAskDelegateToHighlightFireButton() throws {
        // GIVEN
        dialogProvider.dialog = .trackers(message: .init(string: ""), shouldFollowUp: true)
        dialogProvider.state = .showFireButton
        let url = try XCTUnwrap(URL(string: "some.url"))
        let delegate = BrowserTabViewControllerDelegateMock()
        viewController.delegate = delegate
        XCTAssertFalse(delegate.didCallHighlightFireButton)
        tab.navigateTo(url: url)
        wait(for: [expectation], timeout: 3.0)

        // WHEN
        factory.performOnGotItPressed()

        // THEN
        XCTAssertTrue(delegate.didCallHighlightFireButton)
    }

    func testWhenFireButtonPressedThenAskDelegateToRemoveViewHighlights() throws {
        // GIVEN
        dialogProvider.dialog = .tryFireButton
        let url = try XCTUnwrap(URL(string: "some.url"))
        let delegate = BrowserTabViewControllerDelegateMock()
        viewController.delegate = delegate
        XCTAssertFalse(delegate.didCallDismissViewHighlight)
        tab.navigateTo(url: url)
        wait(for: [expectation], timeout: 3.0)

        // WHEN
        factory.performOnFireButtonPressed()

        // THEN
        XCTAssertTrue(delegate.didCallDismissViewHighlight)
    }

}

class MockDialogsProvider: ContextualOnboardingDialogTypeProviding, ContextualOnboardingStateUpdater {
    var state: ContextualOnboardingState = .onboardingCompleted

    func updateStateFor(tab: DuckDuckGo_Privacy_Browser.Tab) {}

    var dialog: ContextualDialogType?

    func dialogTypeForTab(_ tab: Tab, privacyInfo: PrivacyInfo?) -> ContextualDialogType? {
        return dialog
    }

    func gotItPressed() {}

    func fireButtonUsed() {}
}

class CapturingDialogFactory: ContextualDaxDialogsFactory {

    let expectation: XCTestExpectation
    var capturedType: ContextualDialogType?
    var capturedDelegate: OnboardingNavigationDelegate?

    private var onGotItPressed: (() -> Void)?
    private var onFireButtonPressed: (() -> Void)?

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func makeView(for type: ContextualDialogType, delegate: OnboardingNavigationDelegate, onDismiss: @escaping () -> Void, onGotItPressed: @escaping () -> Void, onFireButtonPressed: @escaping () -> Void) -> AnyView {
        capturedType = type
        capturedDelegate = delegate
        self.onGotItPressed = onGotItPressed
        self.onFireButtonPressed = onFireButtonPressed
        expectation.fulfill()
        return AnyView(OnboardingFinalDialog(highFiveAction: {}))
    }

    func performOnGotItPressed() {
        onGotItPressed?()
    }

    func performOnFireButtonPressed() {
        onFireButtonPressed?()
    }

}

final class BrowserTabViewControllerDelegateMock: BrowserTabViewControllerDelegate {
    private(set) var didCallHighlightFireButton = false
    private(set) var didCallDismissViewHighlight = false

    func highlightFireButton() {
        didCallHighlightFireButton = true
    }

    func dismissViewHighlight() {
        didCallDismissViewHighlight = true
    }

}
