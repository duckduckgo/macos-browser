//
//  MacWaitlistLockScreenViewModelTests.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

import XCTest
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import DuckDuckGo_Privacy_Browser

class MacWaitlistLockScreenViewModelTests: XCTestCase {

    private let successResponse = MacWaitlistRedeemSuccessResponse(status: "redeemed")
    
    func testWhenInitializingTheViewModel_ThenStateEqualsRequiresUnlock() {
        let mockStatisticsStore = MockStatisticsStore()
        let mockStore = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore, pixelStore: PixelStoreMock())
        let mockRequest = MockWaitlistRequest(returnedResult: .success(successResponse))
        let viewModel = MacWaitlistLockScreenViewModel(store: mockStore, waitlistRequest: mockRequest)
        
        XCTAssertEqual(viewModel.state, .requiresUnlock)
    }
    
    func testWhenCallingUnlock_ThenStateEqualsUnlockRequestInFlight() {
        let mockStatisticsStore = MockStatisticsStore()
        let mockStore = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore, pixelStore: PixelStoreMock())
        let mockRequest = MockWaitlistRequest(returnedResult: nil)
        let viewModel = MacWaitlistLockScreenViewModel(store: mockStore, waitlistRequest: mockRequest)
        
        viewModel.attemptUnlock(code: "code")
        
        XCTAssertEqual(viewModel.state, .unlockRequestInFlight)
    }
    
    func testWhenCallingUnlockTwice_ThenSecondCallIsIgnored() {
        let mockStatisticsStore = MockStatisticsStore()
        let mockStore = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore, pixelStore: PixelStoreMock())
        let mockRequest = MockWaitlistRequest(returnedResult: nil)
        let viewModel = MacWaitlistLockScreenViewModel(store: mockStore, waitlistRequest: mockRequest)
        
        viewModel.attemptUnlock(code: "code")
        viewModel.attemptUnlock(code: "code")
        
        XCTAssertEqual(viewModel.state, .unlockRequestInFlight)
        XCTAssertEqual(mockRequest.unlockCallsExecuted, 1)
    }
    
    func testWhenCallingUnlock_AndResponseIsSuccessful_ThenStateEqualsUnlockSuccess() {
        let mockStatisticsStore = MockStatisticsStore()
        let mockStore = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore, pixelStore: PixelStoreMock())
        let mockRequest = MockWaitlistRequest(returnedResult: .success(successResponse))
        let viewModel = MacWaitlistLockScreenViewModel(store: mockStore, waitlistRequest: mockRequest)
        
        viewModel.attemptUnlock(code: "code")
        
        XCTAssertEqual(viewModel.state, .unlockSuccess)
    }
    
    func testWhenCallingUnlock_AndResponseIsUnsucessful_ThenStateEqualsUnlockFailure() {
        let mockStatisticsStore = MockStatisticsStore()
        let mockStore = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore, pixelStore: PixelStoreMock())
        let mockRequest = MockWaitlistRequest(returnedResult: .failure(.redemptionError))
        let viewModel = MacWaitlistLockScreenViewModel(store: mockStore, waitlistRequest: mockRequest)
        
        viewModel.attemptUnlock(code: "code")
        
        XCTAssertEqual(viewModel.state, .unlockFailure)
    }
    
    func testWhenCallingUnlock_AndResponseIsSuccessful_ButStatusMessageDoesNotMatch_ThenStateEqualsUnlockSuccess() {
        let mockStatisticsStore = LocalStatisticsStore(pixelDataStore: PixelStoreMock())
        let mockStore = MacWaitlistEncryptedFileStorage(statisticsStore: mockStatisticsStore, pixelStore: PixelStoreMock())
        let almostSuccessResponse = MacWaitlistRedeemSuccessResponse(status: "invalid_message")
        let mockRequest = MockWaitlistRequest(returnedResult: .success(almostSuccessResponse))
        let viewModel = MacWaitlistLockScreenViewModel(store: mockStore, waitlistRequest: mockRequest)
        
        viewModel.attemptUnlock(code: "code")
        
        XCTAssertEqual(viewModel.state, .unlockFailure)
    }

}

private final class MockWaitlistRequest: MacWaitlistRequest {
    
    var unlockCallsExecuted = 0
    
    private let returnedResult: Result<MacWaitlistRedeemSuccessResponse, MacWaitlistRedeemError>?
    
    init(returnedResult: Result<MacWaitlistRedeemSuccessResponse, MacWaitlistRedeemError>?) {
        self.returnedResult = returnedResult
    }
    
    func unlock(with inviteCode: String, completion: @escaping (Result<MacWaitlistRedeemSuccessResponse, MacWaitlistRedeemError>) -> Void) {
        unlockCallsExecuted += 1
        
        if let result = returnedResult {
            completion(result)
        }
    }
    
}
