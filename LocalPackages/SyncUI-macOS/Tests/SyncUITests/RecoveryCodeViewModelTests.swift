//
//  RecoveryCodeViewModelTests.swift
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
@testable import SyncUI_macOS

final class RecoveryCodeViewModelTests: XCTestCase {

    func testSubmitButtonIsDisabledByDefault() throws {
        let model = RecoveryCodeViewModel()
        XCTAssertTrue(model.shouldDisableSubmitButton)
    }

    func testWhenRecoveryCodeIsSetThenSubmitButtonIsEnabled() throws {
        let model = RecoveryCodeViewModel()

        model.setCode("12345")
        XCTAssertFalse(model.shouldDisableSubmitButton)

        model.setCode("")
        XCTAssertTrue(model.shouldDisableSubmitButton)
    }

    func testRecoveryCodeValidation() throws {
        let model = RecoveryCodeViewModel()

        XCTAssertEqual(model.recoveryCode, "")

        model.setCode("12345")
        XCTAssertEqual(model.recoveryCode, "12345")

        model.setCode("Y2hhcmFjdGVycw==")
        XCTAssertEqual(model.recoveryCode, "Y2hhcmFjdGVycw==")

        model.setCode("😍")
        XCTAssertEqual(model.recoveryCode, "Y2hhcmFjdGVycw==")

    }
}
