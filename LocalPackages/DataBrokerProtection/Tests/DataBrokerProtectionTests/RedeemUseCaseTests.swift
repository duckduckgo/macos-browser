//
//  RedeemUseCaseTests.swift
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
import Foundation
@testable import DataBrokerProtection

final class RedeemUseCaseTests: XCTestCase {
    let repository = MockAuthenticationRepository()
    let service = MockAuthenticationService()

    override func tearDown() async throws {
        repository.reset()
        service.reset()
    }

    func testWhenAccessTokenIsNil_thenShouldAskForInviteCodeReturnsTrue() {
        repository.shouldSendNilAccessToken = true

        let sut = RedeemUseCase(authenticationService: service, authenticationRepository: repository)

        XCTAssertFalse(sut.shouldAskForInviteCode())
    }

    func testWhenAccessTokenIsNotNil_thenShouldAskForInviteCodeReturnsFalse() {
        repository.shouldSendNilAccessToken = false

        let sut = RedeemUseCase(authenticationService: service, authenticationRepository: repository)

        XCTAssertFalse(sut.shouldAskForInviteCode())
    }

    func testWhenRedeemSucceds_thenTokenIsSaved() async {
        service.shouldThrow = false
        let sut = RedeemUseCase(authenticationService: service, authenticationRepository: repository)

        try? await sut.redeem(inviteCode: "someInviteCode")

        XCTAssertTrue(repository.wasAccessTokenSaveCalled)
    }

    func testWhenRedeemFails_thenTokenIsNotSaved() async {
        service.shouldThrow = true
        let sut = RedeemUseCase(authenticationService: service, authenticationRepository: repository)

        try? await sut.redeem(inviteCode: "someInviteCode")

        XCTAssertFalse(repository.wasAccessTokenSaveCalled)
    }

    func testWhenGetAuthHeaderHasNoInviteCode_thenThrowsNoInviteCodeError() async {
        repository.shouldSendNilInviteCode = true
        repository.shouldSendNilAccessToken = true

        let sut = RedeemUseCase(authenticationService: service, authenticationRepository: repository)

        let accessToken = try? await sut.getAuthHeader()

        XCTAssertNil(accessToken)
        XCTAssertFalse(service.wasRedeemCalled)
        XCTAssertFalse(repository.wasAccessTokenSaveCalled)
    }

    func testWhenGetAuthHeadersHasEmptyAccessToken_thenWeRedeemAndSave() async {
        repository.shouldSendNilInviteCode = false
        repository.shouldSendNilAccessToken = true
        let sut = RedeemUseCase(authenticationService: service, authenticationRepository: repository)

        _ = try? await sut.getAuthHeader()

        XCTAssertTrue(service.wasRedeemCalled)
        XCTAssertTrue(repository.wasAccessTokenSaveCalled)
    }

    func testWhenGetAuthHeadersHasAccessToken_thenWeReturnHeaderWithoutRedeeming() async {
        repository.shouldSendNilInviteCode = false
        repository.shouldSendNilAccessToken = false
        let sut = RedeemUseCase(authenticationService: service, authenticationRepository: repository)

        let accessToken = try? await sut.getAuthHeader()

        XCTAssertEqual(accessToken, "bearer accessToken")
        XCTAssertFalse(service.wasRedeemCalled)
        XCTAssertFalse(repository.wasAccessTokenSaveCalled)
    }
}
