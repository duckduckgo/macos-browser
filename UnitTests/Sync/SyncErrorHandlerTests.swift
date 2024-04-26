//
//  SyncErrorHandlerTests.swift
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
import DDGSync
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class SyncErrorHandlerTests: XCTestCase {

    var cancellables: Set<AnyCancellable>!
    var handler: SyncErrorHandler!
    var alertPresenter: CapturingAlertPresenter!
    let userDefaults = UserDefaults(suiteName: "\(Bundle.main.bundleIdentifier!).\(NSApplication.runType)")!

    override func setUpWithError() throws {
        UserDefaultsWrapper<Any>.clearAll()
        cancellables = []
        alertPresenter = CapturingAlertPresenter()
        handler = SyncErrorHandler(alertPresenter: alertPresenter)
    }

    override func tearDownWithError() throws {
        cancellables = nil
        alertPresenter = nil
        handler = nil
    }

    func testInitialization_DefaultsNotSet() {
        let handler = SyncErrorHandler()
        XCTAssertFalse(handler.isSyncBookmarksPaused)
        XCTAssertFalse(handler.isSyncCredentialsPaused)
        XCTAssertFalse(handler.isSyncPaused)
    }

    func test_WhenIsSyncBookmarksPaused_ThenSyncPausedChangedPublisherIsTriggered() async {
        let expectation = XCTestExpectation(description: "syncPausedChangedPublisher")
        handler.syncPausedChangedPublisher
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        handler.handleBookmarkError(SyncError.unexpectedStatusCode(409))

        await self.fulfillment(of: [expectation], timeout: 4.0)
        XCTAssertTrue(handler.isSyncBookmarksPaused)
    }

    func test_WhenIsSyncCredentialsPaused_ThenSyncPausedChangedPublisherIsTriggered() async {
        let expectation = XCTestExpectation(description: "syncPausedChangedPublisher")
        handler.syncPausedChangedPublisher
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        handler.handleCredentialError(SyncError.unexpectedStatusCode(409))

        await self.fulfillment(of: [expectation], timeout: 4.0)
        XCTAssertTrue(handler.isSyncCredentialsPaused)
    }

    func test_WhenIsSyncPaused_ThenSyncPausedChangedPublisherIsTriggered() async {
        let expectation = XCTestExpectation(description: "syncPausedChangedPublisher")

        handler.syncPausedChangedPublisher
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        handler.handleBookmarkError(SyncError.unexpectedStatusCode(401))

        await self.fulfillment(of: [expectation], timeout: 4.0)
        XCTAssertTrue(handler.isSyncPaused)
    }

    func test_WhenHandleBookmarksError409_ThenIsSyncBookmarksPausedIsUpdatedToTrue() async {
        let error = SyncError.unexpectedStatusCode(409)

        handler.handleBookmarkError(error)

        XCTAssertTrue(handler.isSyncBookmarksPaused)
        XCTAssertFalse(handler.isSyncCredentialsPaused)
        XCTAssertFalse(handler.isSyncPaused)
    }

    func test_WhenHandleCredentialsError409_ThenIsSyncCredentialsPausedIsUpdatedToTrue() async {
        let error = SyncError.unexpectedStatusCode(409)

        handler.handleCredentialError(error)

        XCTAssertFalse(handler.isSyncBookmarksPaused)
        XCTAssertTrue(handler.isSyncCredentialsPaused)
        XCTAssertFalse(handler.isSyncPaused)
    }

    func test_WhenHandleBookmarksError413_ThenIsSyncBookmarksPausedIsUpdatedToTrue() async {
        let error = SyncError.unexpectedStatusCode(413)

        handler.handleBookmarkError(error)

        XCTAssertTrue(handler.isSyncBookmarksPaused)
        XCTAssertFalse(handler.isSyncCredentialsPaused)
        XCTAssertFalse(handler.isSyncPaused)
    }

    func test_WhenHandleCredentialsError413_ThenIsSyncCredentialsPausedIsUpdatedToTrue() async {
        let error = SyncError.unexpectedStatusCode(413)

        handler.handleCredentialError(error)

        XCTAssertFalse(handler.isSyncBookmarksPaused)
        XCTAssertTrue(handler.isSyncCredentialsPaused)
        XCTAssertFalse(handler.isSyncPaused)
    }

    func test_WhenHandleBookmarksError401_ThenIsSyncPausedIsUpdatedToTrue() async {
        let error = SyncError.unexpectedStatusCode(401)

        handler.handleBookmarkError(error)

        XCTAssertFalse(handler.isSyncBookmarksPaused)
        XCTAssertFalse(handler.isSyncCredentialsPaused)
        XCTAssertTrue(handler.isSyncPaused)
    }

    func test_WhenHandleCredentialsError401_ThenIsSyncIsPausedIsUpdatedToTrue() async {
        let error = SyncError.unexpectedStatusCode(401)

        handler.handleCredentialError(error)

        XCTAssertFalse(handler.isSyncBookmarksPaused)
        XCTAssertFalse(handler.isSyncCredentialsPaused)
        XCTAssertTrue(handler.isSyncPaused)
    }

    func test_WhenHandleBookmarksError418_ThenIsSyncPausedIsUpdatedToTrue() async {
        let error = SyncError.unexpectedStatusCode(418)

        handler.handleBookmarkError(error)

        XCTAssertFalse(handler.isSyncBookmarksPaused)
        XCTAssertFalse(handler.isSyncCredentialsPaused)
        XCTAssertTrue(handler.isSyncPaused)
    }

    func test_WhenHandleCredentialsError418_ThenIsSyncIsPausedIsUpdatedToTrue() async {
        let error = SyncError.unexpectedStatusCode(418)

        handler.handleCredentialError(error)

        XCTAssertFalse(handler.isSyncBookmarksPaused)
        XCTAssertFalse(handler.isSyncCredentialsPaused)
        XCTAssertTrue(handler.isSyncPaused)
    }

    func test_WhenHandleBookmarksError429_ThenIsSyncPausedIsUpdatedToTrue() async {
        let error = SyncError.unexpectedStatusCode(429)

        handler.handleBookmarkError(error)

        XCTAssertFalse(handler.isSyncBookmarksPaused)
        XCTAssertFalse(handler.isSyncCredentialsPaused)
        XCTAssertTrue(handler.isSyncPaused)
    }

    func test_WhenHandleCredentialsError429_ThenIsSyncIsPausedIsUpdatedToTrue() async {
        let error = SyncError.unexpectedStatusCode(429)

        handler.handleCredentialError(error)

        XCTAssertFalse(handler.isSyncBookmarksPaused)
        XCTAssertFalse(handler.isSyncCredentialsPaused)
        XCTAssertTrue(handler.isSyncPaused)
    }

    func test_WhenHandleBookmarksError400_ThenIsSyncPausedIsUpdatedToTrue() async {
        let error = SyncError.unexpectedStatusCode(400)

        handler.handleBookmarkError(error)

        XCTAssertFalse(handler.isSyncBookmarksPaused)
        XCTAssertFalse(handler.isSyncCredentialsPaused)
        XCTAssertTrue(handler.isSyncPaused)
    }

    func test_WhenHandleCredentialsError400_ThenIsSyncIsPausedIsUpdatedToTrue() async {
        let error = SyncError.unexpectedStatusCode(400)

        handler.handleCredentialError(error)

        XCTAssertFalse(handler.isSyncBookmarksPaused)
        XCTAssertFalse(handler.isSyncCredentialsPaused)
        XCTAssertTrue(handler.isSyncPaused)
    }

    func test_WhenHandleBookmarksError409ForTheFirstTime_ThenAlertShown() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let error = SyncError.unexpectedStatusCode(409)

        Task {
            handler.handleBookmarkError(error)
            expectation.fulfill()
        }

        await self.fulfillment(of: [expectation], timeout: 4.0)
        XCTAssertTrue(alertPresenter.showAlertCalled)
    }

    func test_WhenHandleBookmarksError409ForTheSecondTime_ThenAlertNotShown() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let expectation2 = XCTestExpectation(description: "Second Error handled")
        let error = SyncError.unexpectedStatusCode(409)

        Task {
            handler.handleBookmarkError(error)
            expectation.fulfill()
        }

        handler = SyncErrorHandler(alertPresenter: alertPresenter)

        Task {
            handler.handleBookmarkError(error)
            expectation2.fulfill()
        }

        await self.fulfillment(of: [expectation, expectation2], timeout: 4.0)
        XCTAssertEqual(alertPresenter.showAlertCount, 1)
    }

    func test_WhenHandleCredentialsError409ForTheFirstTime_ThenAlertShown() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let error = SyncError.unexpectedStatusCode(409)

        Task {
            handler.handleCredentialError(_:)(error)
            expectation.fulfill()
        }

        await self.fulfillment(of: [expectation], timeout: 4.0)
        XCTAssertTrue(alertPresenter.showAlertCalled)
    }

    func test_WhenHandleCredentialsError409ForTheSecondTime_ThenAlertNotShown() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let expectation2 = XCTestExpectation(description: "Second Error handled")
        let error = SyncError.unexpectedStatusCode(409)

        Task {
            handler.handleCredentialError(error)
            expectation.fulfill()
        }

        handler = SyncErrorHandler(alertPresenter: alertPresenter)

        Task {
            handler.handleCredentialError(error)
            expectation2.fulfill()
        }

        await self.fulfillment(of: [expectation, expectation2], timeout: 4.0)
        XCTAssertEqual(alertPresenter.showAlertCount, 1)
    }

    func test_WhenHandleBookmarksError413ForTheFirstTime_ThenAlertShown() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let error = SyncError.unexpectedStatusCode(413)

        Task {
            handler.handleBookmarkError(error)
            expectation.fulfill()
        }

        await self.fulfillment(of: [expectation], timeout: 4.0)
        XCTAssertTrue(alertPresenter.showAlertCalled)
    }

    func test_WhenHandleBookmarksError413ForTheSecondTime_ThenAlertNotShown() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let expectation2 = XCTestExpectation(description: "Second Error handled")
        let error = SyncError.unexpectedStatusCode(413)

        Task {
            handler.handleBookmarkError(error)
            expectation.fulfill()
        }

        handler = SyncErrorHandler(alertPresenter: alertPresenter)

        Task {
            handler.handleBookmarkError(error)
            expectation2.fulfill()
        }

        await self.fulfillment(of: [expectation, expectation2], timeout: 4.0)
        XCTAssertEqual(alertPresenter.showAlertCount, 1)
    }

    func test_WhenHandleCredentialsError413ForTheFirstTime_ThenAlertShown() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let error = SyncError.unexpectedStatusCode(413)

        Task {
            handler.handleCredentialError(_:)(error)
            expectation.fulfill()
        }

        await self.fulfillment(of: [expectation], timeout: 4.0)
        XCTAssertTrue(alertPresenter.showAlertCalled)
    }

    func test_WhenHandleCredentialsError413ForTheSecondTime_ThenAlertNotShown() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let expectation2 = XCTestExpectation(description: "Second Error handled")
        let error = SyncError.unexpectedStatusCode(413)

        Task {
            handler.handleCredentialError(error)
            expectation.fulfill()
        }

        handler = SyncErrorHandler(alertPresenter: alertPresenter)

        Task {
            handler.handleCredentialError(error)
            expectation2.fulfill()
        }

        await self.fulfillment(of: [expectation, expectation2], timeout: 4.0)
        XCTAssertEqual(alertPresenter.showAlertCount, 1)
    }

    func test_WhenHandleCredentialsError413_AndThenHandleBookmarksError413_ThenAlertShownTwice() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let expectation2 = XCTestExpectation(description: "Second Error handled")
        let error = SyncError.unexpectedStatusCode(413)

        Task {
            handler.handleCredentialError(error)
            expectation.fulfill()
        }

        handler = SyncErrorHandler(alertPresenter: alertPresenter)

        Task {
            handler.handleBookmarkError(_:)(error)
            expectation2.fulfill()
        }

        await self.fulfillment(of: [expectation, expectation2], timeout: 4.0)
        XCTAssertEqual(alertPresenter.showAlertCount, 2)
    }

    func test_WhenHandleCredentialsError401ForTheFirstTime_ThenAlertShown() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let error = SyncError.unexpectedStatusCode(401)

        Task {
            handler.handleCredentialError(_:)(error)
            expectation.fulfill()
        }

        await self.fulfillment(of: [expectation], timeout: 4.0)
        XCTAssertTrue(alertPresenter.showAlertCalled)
    }

    func test_WhenHandleBookmarksError401ForTheSecondTime_ThenNoAlertShown() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let expectation2 = XCTestExpectation(description: "Second Error handled")
        let error = SyncError.unexpectedStatusCode(401)

        Task {
            handler.handleBookmarkError(_:)(error)
            expectation.fulfill()
        }

        handler = SyncErrorHandler(alertPresenter: alertPresenter)

        Task {
            handler.handleBookmarkError(_:)(error)
            expectation2.fulfill()
        }

        await self.fulfillment(of: [expectation, expectation2], timeout: 4.0)
        XCTAssertEqual(alertPresenter.showAlertCount, 1)
    }

    func test_WhenHandleCredentialsError400ForTheFirstTime_ThenNoAlertShown() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let error = SyncError.unexpectedStatusCode(400)

        Task {
            handler.handleCredentialError(_:)(error)
            expectation.fulfill()
        }

        await self.fulfillment(of: [expectation], timeout: 4.0)
        XCTAssertFalse(alertPresenter.showAlertCalled)
    }

    func test_WhenHandleBookarksError418ForTheFirstTime_ThenNoAlertShown() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let error = SyncError.unexpectedStatusCode(418)

        Task {
            handler.handleCredentialError(_:)(error)
            expectation.fulfill()
        }

        await self.fulfillment(of: [expectation], timeout: 4.0)
        XCTAssertFalse(alertPresenter.showAlertCalled)
    }

    func test_WhenHandleBookarksError429ForTheFirstTime_ThenNoAlertShown() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let error = SyncError.unexpectedStatusCode(429)

        Task {
            handler.handleCredentialError(_:)(error)
            expectation.fulfill()
        }

        await self.fulfillment(of: [expectation], timeout: 4.0)
        XCTAssertFalse(alertPresenter.showAlertCalled)
    }

    func test_When400ErrorFired9Times_ThenNoAlertShown() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let error = SyncError.unexpectedStatusCode(400)

        Task {
            for _ in 0...8 {
                handler.handleCredentialError(_:)(error)
            }
            expectation.fulfill()
        }

        await self.fulfillment(of: [expectation], timeout: 8.0)
        XCTAssertFalse(alertPresenter.showAlertCalled)
    }

    func test_When400ErrorFired10Times_ThenAlertShown() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let error = SyncError.unexpectedStatusCode(400)

        Task {
            for _ in 0...9 {
                handler.handleCredentialError(_:)(error)
            }
            expectation.fulfill()
        }

        await self.fulfillment(of: [expectation], timeout: 8.0)
        let currentTime = Date()
        let timeDifference = currentTime.timeIntervalSince(userDefaults.value(forKey: UserDefaultsWrapper<Date>.Key.syncLastErrorNotificationTime.rawValue) as! Date)
        XCTAssertTrue(alertPresenter.showAlertCalled)
        XCTAssertTrue(abs(timeDifference) <= 5)
    }

    func test_When400ErrorFired10TimesTwice_ThenAlertShownOnce() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let error = SyncError.unexpectedStatusCode(400)

        Task {
            for _ in 0...20 {
                handler.handleCredentialError(_:)(error)
            }
            expectation.fulfill()
        }

        await self.fulfillment(of: [expectation], timeout: 8.0)
        XCTAssertEqual(alertPresenter.showAlertCount, 1)
    }

    func test_whenSyncBookmarksSucced_ThenDateSaved() {
        handler.syncBookmarksSucceded()
        let actualTime =  userDefaults.value(forKey: UserDefaultsWrapper<Date>.Key.syncLastSuccesfullTime.rawValue) as! Date
        let currentTime = Date()
        let timeDifference = currentTime.timeIntervalSince(actualTime)

        XCTAssertNotNil(actualTime)
        XCTAssertTrue(abs(timeDifference) <= 5)
    }

    func test_whenSyncBookmarksSucced_ThenError401AlertCanBeShownAgain() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let expectation2 = XCTestExpectation(description: "Secons Error handled")
        let error = SyncError.unexpectedStatusCode(401)

        Task {
            handler.handleBookmarkError(_:)(error)
            expectation.fulfill()
        }

        await self.fulfillment(of: [expectation], timeout: 4.0)
        XCTAssertTrue(handler.isSyncPaused)
        XCTAssertEqual(alertPresenter.showAlertCount, 1)
        handler.syncBookmarksSucceded()

        Task {
            handler.handleBookmarkError(_:)(error)
            expectation2.fulfill()
        }

        await self.fulfillment(of: [expectation2], timeout: 4.0)
        XCTAssertTrue(handler.isSyncPaused)
        XCTAssertEqual(alertPresenter.showAlertCount, 2)
    }

    func test_whenSyncBookmarksSucced_ThenError409AlertCanBeShownAgain() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let expectation2 = XCTestExpectation(description: "Secons Error handled")
        let error = SyncError.unexpectedStatusCode(409)

        Task {
            handler.handleBookmarkError(_:)(error)
            expectation.fulfill()
        }

        await self.fulfillment(of: [expectation], timeout: 4.0)
        XCTAssertTrue(handler.isSyncBookmarksPaused)
        XCTAssertEqual(alertPresenter.showAlertCount, 1)
        handler.syncBookmarksSucceded()

        Task {
            handler.handleBookmarkError(_:)(error)
            expectation2.fulfill()
        }

        await self.fulfillment(of: [expectation2], timeout: 4.0)
        XCTAssertTrue(handler.isSyncBookmarksPaused)
        XCTAssertEqual(alertPresenter.showAlertCount, 2)
    }

    func test_whenSyncCredentialsSucced_ThenError413AlertCanBeShownAgain() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let expectation2 = XCTestExpectation(description: "Secons Error handled")
        let error = SyncError.unexpectedStatusCode(413)

        Task {
            handler.handleCredentialError(_:)(error)
            expectation.fulfill()
        }

        await self.fulfillment(of: [expectation], timeout: 4.0)
        XCTAssertTrue(handler.isSyncCredentialsPaused)
        XCTAssertEqual(alertPresenter.showAlertCount, 1)
        handler.syncCredentialsSucceded()

        Task {
            handler.handleCredentialError(_:)(error)
            expectation2.fulfill()
        }

        await self.fulfillment(of: [expectation2], timeout: 4.0)
        XCTAssertTrue(handler.isSyncCredentialsPaused)
        XCTAssertEqual(alertPresenter.showAlertCount, 2)
    }

    func test_whenCredentialsSucced_ThenDateSaved() {
        handler.syncCredentialsSucceded()
        let actualTime =  userDefaults.value(forKey: UserDefaultsWrapper<Date>.Key.syncLastSuccesfullTime.rawValue) as! Date
        let currentTime = Date()
        let timeDifference = currentTime.timeIntervalSince(actualTime)

        XCTAssertNotNil(actualTime)
        XCTAssertTrue(abs(timeDifference) <= 5)
    }

    func test_When400ErrorFiredAfter12HoursFromLastSuccessfulSync_ThenAlertShown() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let expectation2 = XCTestExpectation(description: "Second Error handled")
        let error = SyncError.unexpectedStatusCode(400)
        let thirteenHoursAgo = Calendar.current.date(byAdding: .hour, value: -13, to: Date())!
        Task {
            handler.handleCredentialError(_:)(error)
            expectation.fulfill()
        }

        userDefaults.set(thirteenHoursAgo, forKey: UserDefaultsWrapper<Date>.Key.syncLastSuccesfullTime.rawValue)

        Task {
            handler.handleCredentialError(_:)(error)
            expectation2.fulfill()
        }

        await self.fulfillment(of: [expectation, expectation2], timeout: 4.0)
        XCTAssertTrue(alertPresenter.showAlertCalled)
        XCTAssertEqual(alertPresenter.showAlertCount, 1)
    }

    func test_When400ErrorFiredAfter12HoursFromLastSuccessfulSync_ButNoErrorRegisteredBefore_ThenNoAlertShown() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let error = SyncError.unexpectedStatusCode(400)
        let thirteenHoursAgo = Calendar.current.date(byAdding: .hour, value: -13, to: Date())!
        userDefaults.set(thirteenHoursAgo, forKey: UserDefaultsWrapper<Date>.Key.syncLastSuccesfullTime.rawValue)

        Task {
            handler.handleCredentialError(_:)(error)
            expectation.fulfill()
        }

        await self.fulfillment(of: [expectation], timeout: 4.0)
        XCTAssertFalse(alertPresenter.showAlertCalled)
    }

    func test_When400ErrorFired10Times_AndAfter24H_400ErrorFired10TimesAgain_ThenAlertShownTwice() async {
        let expectation = XCTestExpectation(description: "Error handled")
        let expectation2 = XCTestExpectation(description: "SecondError handled")
        let error = SyncError.unexpectedStatusCode(400)

        Task {
            for _ in 0...9 {
                handler.handleCredentialError(_:)(error)
            }
            expectation.fulfill()
        }

        await self.fulfillment(of: [expectation], timeout: 4.0)
        XCTAssertTrue(alertPresenter.showAlertCalled)
        let oneDayAgo = Calendar.current.date(byAdding: .hour, value: -25, to: Date())!
        userDefaults.set(oneDayAgo, forKey: UserDefaultsWrapper<Date>.Key.syncLastErrorNotificationTime.rawValue)

        Task {
            for _ in 0...9 {
                handler.handleCredentialError(_:)(error)
            }
            expectation2.fulfill()
        }

        await self.fulfillment(of: [expectation2], timeout: 4.0)
        XCTAssertTrue(alertPresenter.showAlertCalled)
        XCTAssertEqual(alertPresenter.showAlertCount, 2)
    }

    func test_whenSyncTurnedOff_errorsAreReset() {
        handler.handleCredentialError(_:)(SyncError.unexpectedStatusCode(409))
        handler.handleBookmarkError(_:)(SyncError.unexpectedStatusCode(409))
        handler.handleBookmarkError(_:)(SyncError.unexpectedStatusCode(401))

        userDefaults.set(Date(), forKey: UserDefaultsWrapper<Date>.Key.syncLastErrorNotificationTime.rawValue)
        userDefaults.set(true, forKey: UserDefaultsWrapper<Bool>.Key.syncBookmarksPausedErrorDisplayed.rawValue)
        userDefaults.set(true, forKey: UserDefaultsWrapper<Bool>.Key.syncCredentialsPausedErrorDisplayed.rawValue)
        userDefaults.set(true, forKey: UserDefaultsWrapper<Bool>.Key.syncInvalidLoginPausedErrorDisplayed.rawValue)
        userDefaults.set(true, forKey: UserDefaultsWrapper<Date>.Key.syncLastErrorNotificationTime.rawValue)
        userDefaults.set(6, forKey: UserDefaultsWrapper<Int>.Key.syncLastNonActionableErrorCount.rawValue)

        handler.syncDidTurnOff()

        XCTAssertFalse(handler.isSyncBookmarksPaused)
        XCTAssertFalse(handler.isSyncCredentialsPaused)
        XCTAssertFalse(handler.isSyncPaused)

        XCTAssertNil(userDefaults.value(forKey: UserDefaultsWrapper<Date>.Key.syncLastSuccesfullTime.rawValue))
        XCTAssertFalse(userDefaults.bool(forKey: UserDefaultsWrapper<Bool>.Key.syncBookmarksPausedErrorDisplayed.rawValue))
        XCTAssertFalse(userDefaults.bool(forKey: UserDefaultsWrapper<Bool>.Key.syncCredentialsPausedErrorDisplayed.rawValue))
        XCTAssertFalse(userDefaults.bool(forKey: UserDefaultsWrapper<Bool>.Key.syncInvalidLoginPausedErrorDisplayed.rawValue))
        XCTAssertNil(userDefaults.value(forKey: UserDefaultsWrapper<Date>.Key.syncLastErrorNotificationTime.rawValue))
        XCTAssertEqual(userDefaults.integer(forKey: UserDefaultsWrapper<Int>.Key.syncLastNonActionableErrorCount.rawValue), 0)
    }
}

class CapturingAlertPresenter: AlertPresenter {
    var showAlertCalled = false
    var capturedAlert: NSAlert?
    var showAlertCount = 0
    func showAlert(_ alert: NSAlert) {
        showAlertCalled = true
        capturedAlert = alert
        showAlertCount += 1
    }
}
