//
//  PixelKitParametersTests.swift
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
@testable import PixelKit
import PixelKitTestingUtilities

final class PixelKitParametersTests: XCTestCase {

    /// Test events for convenience
    ///
    private enum TestEvent: PixelKitEventV2 {
        case errorEvent(error: Error)

        var name: String {
            switch self {
            case .errorEvent:
                return "error_event"
            }
        }

        var parameters: [String: String]? {
            nil
        }

        var error: Error? {
            switch self {
            case .errorEvent(let error):
                error
            }
        }
    }

    /// Test that when firing pixels that include multiple levels of underlying error information, all levels
    /// are properly included in the pixel.
    ///
    func testUnderlyingErrorInformationParameters() {
        let underlyingError3 = NSError(domain: "test", code: 3)
        let underlyingError2 = NSError(
            domain: "test",
            code: 2,
            userInfo: [
                NSUnderlyingErrorKey: underlyingError3 as NSError
            ])
        let topLevelError = NSError(
            domain: "test",
            code: 1,
            userInfo: [
                NSUnderlyingErrorKey: underlyingError2 as NSError
            ])

        fire(TestEvent.errorEvent(error: topLevelError),
             frequency: .standard,
             and: .expect(pixelName: "m_mac_error_event",
                          error: topLevelError,
                          underlyingErrors: [underlyingError2, underlyingError3]),
             file: #filePath,
             line: #line)
    }
}
