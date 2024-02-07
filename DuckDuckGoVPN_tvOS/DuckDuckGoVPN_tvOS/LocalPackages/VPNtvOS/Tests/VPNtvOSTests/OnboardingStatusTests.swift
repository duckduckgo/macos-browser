//
//  OnboardingStatusTests.swift
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

import Foundation
import XCTest
@testable import NetworkProtectionUI

final class OnboardingStatusTests: XCTestCase {

    /// Since raw values for `OnboardingStatus` are calculated dynamically, this test
    /// tests the the conversion from status to raw value and back.
    ///
    func testOnboardingStatusRawValues() {
        let allStatus: [OnboardingStatus] = [
            .completed,
            .isOnboarding(step: .userNeedsToAllowExtension),
            .isOnboarding(step: .userNeedsToAllowVPNConfiguration)
        ]

        for status in allStatus {
            let rawValue = status.rawValue
            let newStatus = OnboardingStatus(rawValue: rawValue)

            XCTAssertEqual(status, newStatus)
        }
    }
}
