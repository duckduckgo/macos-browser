//
//  TabBarRemoteMessageViewModelTests.swift
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
import Combine
import RemoteMessaging
@testable import DuckDuckGo_Privacy_Browser

class TabBarRemoteMessageViewModelTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    func testWhenModelIsNotForTabBar_thenIsNotSetAsRemoteMessage() {
        let mock = MockTabBarRemoteMessageProvider()
        let viewModel = TabBarRemoteMessageViewModel(activeRemoteMessageModel: mock, isFireWindow: false)
        let expectation = XCTestExpectation(description: "Publisher should emit a nil value")

        viewModel.$remoteMessage
            .sink { remoteMesssage in
                if remoteMesssage == nil {
                    expectation.fulfill()
                }
            }.store(in: &cancellables)

        mock.emitRemoteMessage(createOtherRemoteMessage())

        wait(for: [expectation], timeout: 1.0)
    }

    func testWhenModelIsForTabBarButIsMalformed_thenIsNotSetAsRemoteMessage() {
        let mock = MockTabBarRemoteMessageProvider()
        let viewModel = TabBarRemoteMessageViewModel(activeRemoteMessageModel: mock, isFireWindow: false)
        let expectation = XCTestExpectation(description: "Publisher should emit a nil value")

        viewModel.$remoteMessage
            .sink { remoteMesssage in
                if remoteMesssage == nil {
                    expectation.fulfill()
                }
            }.store(in: &cancellables)

        mock.emitRemoteMessage(createMalformedTabBarRemoteMessage())

        wait(for: [expectation], timeout: 1.0)
    }

    func testWhenWindowIsFireWindow_thenIsNotSetAsRemoteMessage() {
        let mock = MockTabBarRemoteMessageProvider()
        let viewModel = TabBarRemoteMessageViewModel(activeRemoteMessageModel: mock, isFireWindow: true)
        let expectation = XCTestExpectation(description: "Publisher should emit a nil value")

        viewModel.$remoteMessage
            .sink { remoteMesssage in
                if remoteMesssage == nil {
                    expectation.fulfill()
                }
            }.store(in: &cancellables)

        mock.emitRemoteMessage(createTabBarRemoteMessage())

        wait(for: [expectation], timeout: 1.0)
    }

    func testWhenTabBarRemoteMessageIsCorrect_thenIsSet() {
        let mock = MockTabBarRemoteMessageProvider()
        let viewModel = TabBarRemoteMessageViewModel(activeRemoteMessageModel: mock, isFireWindow: false)
        let expectation = XCTestExpectation(description: "Publisher should not emit a value")

        viewModel.$remoteMessage
            .sink { remoteMesssage in
                if remoteMesssage != nil {
                    expectation.fulfill()
                }
            }.store(in: &cancellables)

        mock.emitRemoteMessage(createTabBarRemoteMessage())

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Utilities

    private func createTabBarRemoteMessage() -> RemoteMessageModel {
        let tabBarRemoteMessageContent: RemoteMessageModelType = .bigSingleAction(titleText: "Help Us Improve",
                                                                                  descriptionText: "We really want to know which features would make our browser better.",
                                                                                  placeholder: .announce,
                                                                                  primaryActionText: "Tell Us What You Think",
                                                                                  primaryAction: .survey(value: "www.survey.com"))
        return RemoteMessageModel(id: TabBarRemoteMessage.tabBarPermanentSurveyRemoteMessageId,
                                  content: tabBarRemoteMessageContent,
                                  matchingRules: [Int](),
                                  exclusionRules: [Int](),
                                  isMetricsEnabled: true)
    }

    private func createMalformedTabBarRemoteMessage() -> RemoteMessageModel {
        let tabBarRemoteMessageContent: RemoteMessageModelType = .bigSingleAction(titleText: "Help Us Improve",
                                                                                  descriptionText: "We really want to know which features would make our browser better.",
                                                                                  placeholder: .announce,
                                                                                  primaryActionText: "Tell Us What You Think",
                                                                                  primaryAction: .appStore)
        return RemoteMessageModel(id: TabBarRemoteMessage.tabBarPermanentSurveyRemoteMessageId,
                                  content: tabBarRemoteMessageContent,
                                  matchingRules: [Int](),
                                  exclusionRules: [Int](),
                                  isMetricsEnabled: true)
    }

    private func createOtherRemoteMessage() -> RemoteMessageModel {
        let tabBarRemoteMessageContent: RemoteMessageModelType = .bigSingleAction(titleText: "Some title!",
                                                                                  descriptionText: "Some description",
                                                                                  placeholder: .announce,
                                                                                  primaryActionText: "Primary!",
                                                                                  primaryAction: .survey(value: "www.survey.com"))
        return RemoteMessageModel(id: "other_id",
                                  content: tabBarRemoteMessageContent,
                                  matchingRules: [Int](),
                                  exclusionRules: [Int](),
                                  isMetricsEnabled: true)
    }
}

class MockTabBarRemoteMessageProvider: TabBarRemoteMessageProviding {
    private let remoteMessageSubject = PassthroughSubject<RemoteMessageModel?, Never>()

    var remoteMessagePublisher: AnyPublisher<RemoteMessageModel?, Never> {
        return remoteMessageSubject.eraseToAnyPublisher()
    }

    func emitRemoteMessage(_ message: RemoteMessageModel?) {
        remoteMessageSubject.send(message)
    }

    func markRemoteMessageAsShown() async {
        // No-op
    }

    func onSurveyOpened() async {
        // No-op
    }

    func onMessageDismissed() async {
        // No-op
    }
}
