//
//  WaitlistViewModelTests.swift
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

final class WaitlistViewModelTests: XCTestCase {

    // MARK: - Initial State Tests

    @MainActor
    func testWhenTimestampIsNotPresent_ThenStateIsNotJoinedQueue() async {
        let request = MockWaitlistRequest.failure()
        let storage = MockWaitlistStorage()
        let viewModel = WaitlistViewModel(waitlistRequest: request,
                                                           waitlistStorage: storage,
                                                           notificationService: MockNotificationService(),
                                                           showNotificationSuccessState: true,
                                                           termsAndConditionActionHandler: MockWaitlistTermsAndConditionsActionHandler(),
                                                           featureSetupHandler: MockWaitlistFeatureSetupHandler())

        await viewModel.updateViewState()

        XCTAssertEqual(viewModel.viewState, .notOnWaitlist)
    }

    @MainActor
    func testWhenTimestampIsPresentAndInviteCodeIsNil_ThenStateIsJoinedQueue() async {
        let request = MockWaitlistRequest.failure()
        let storage = MockWaitlistStorage()
        storage.store(waitlistTimestamp: 12345)
        let notificationService = MockNotificationService(authorizationStatus: .authorized)

        let viewModel = WaitlistViewModel(waitlistRequest: request,
                                                           waitlistStorage: storage,
                                                           notificationService: notificationService,
                                                           showNotificationSuccessState: true,
                                                           termsAndConditionActionHandler: MockWaitlistTermsAndConditionsActionHandler(),
                                                           featureSetupHandler: MockWaitlistFeatureSetupHandler())

        await viewModel.updateViewState()

        XCTAssertEqual(viewModel.viewState, .joinedWaitlist(.notificationAllowed))
    }

    @MainActor
    func testWhenTimestampIsPresentAndInviteCodeIsPresent_ThenStateIsInvited() async {
        let request = MockWaitlistRequest.failure()
        let storage = MockWaitlistStorage()
        storage.store(waitlistTimestamp: 12345)
        storage.store(waitlistToken: "token")
        storage.store(inviteCode: "ABCD1234")
        let notificationService = MockNotificationService(authorizationStatus: .authorized)

        let viewModel = WaitlistViewModel(waitlistRequest: request,
                                                           waitlistStorage: storage,
                                                           notificationService: notificationService,
                                                           showNotificationSuccessState: true,
                                                           termsAndConditionActionHandler: MockWaitlistTermsAndConditionsActionHandler(),
                                                           featureSetupHandler: MockWaitlistFeatureSetupHandler())

        await viewModel.updateViewState()

        XCTAssertEqual(viewModel.viewState, .invited)
    }

    // MARK: - Action Tests

    @MainActor
    func testWhenJoinQueueIsCalled_ThenViewStateIsUpdatedToJoinedQueue() async {
        let request = MockWaitlistRequest.returning(.success(.init(token: "token", timestamp: 12345)))
        let storage = MockWaitlistStorage()
        var notificationService = MockNotificationService()
        notificationService.authorizationStatus = .notDetermined
        let viewModel = WaitlistViewModel(waitlistRequest: request,
                                                           waitlistStorage: storage,
                                                           notificationService: notificationService,
                                                           showNotificationSuccessState: true,
                                                           termsAndConditionActionHandler: MockWaitlistTermsAndConditionsActionHandler(),
                                                           featureSetupHandler: MockWaitlistFeatureSetupHandler())

        var stateUpdates: [WaitlistViewModel.ViewState] = []
        let cancellable = viewModel.$viewState.sink { stateUpdates.append($0) }

        await viewModel.perform(action: .joinQueue)
        cancellable.cancel()

        XCTAssertEqual(stateUpdates, [.notOnWaitlist, .joiningWaitlist, .joinedWaitlist(.notDetermined)])
    }

    @MainActor
    func testWhenAcceptingTermsAndConditions_ThenAuthTokenIsFetched_AndTermsAndConditionsAreMarkedAsAccepted() async {
        let request = MockWaitlistRequest.failure()
        let storage = MockWaitlistStorage()
        storage.store(waitlistTimestamp: 12345)
        storage.store(waitlistToken: "token")
        storage.store(inviteCode: "ABCD1234")
        let notificationService = MockNotificationService(authorizationStatus: .authorized)

        let viewModel = WaitlistViewModel(waitlistRequest: request,
                                                           waitlistStorage: storage,
                                                           notificationService: notificationService,
                                                           showNotificationSuccessState: true,
                                                           termsAndConditionActionHandler: MockWaitlistTermsAndConditionsActionHandler(),
                                                           featureSetupHandler: MockWaitlistFeatureSetupHandler())

        await viewModel.updateViewState()
        XCTAssertEqual(viewModel.viewState, .invited)

        await viewModel.perform(action: .acceptTermsAndConditions)
        XCTAssertEqual(viewModel.viewState, .readyToEnable)
    }

}
