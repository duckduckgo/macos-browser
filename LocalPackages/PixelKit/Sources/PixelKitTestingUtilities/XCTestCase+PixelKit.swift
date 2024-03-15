//
//  XCTestCase+PixelKit.swift
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
@testable import PixelKit
import XCTest

public extension XCTestCase {

    // MARK: - Parameters

    /// List of standard pixel parameters.
    ///
    /// This is useful to support filtering these parameters out if needed.
    ///
    private static var standardPixelParameters = [
        PixelKit.Parameters.appVersion,
        PixelKit.Parameters.pixelSource,
        PixelKit.Parameters.test
    ]

    /// List of errror pixel parameters
    ///
    private static var errorPixelParameters = [
        PixelKit.Parameters.errorCode,
        PixelKit.Parameters.errorDomain
    ]

    /// List of underlying error pixel parameters
    ///
    private static var underlyingErrorPixelParameters = [
        PixelKit.Parameters.underlyingErrorCode,
        PixelKit.Parameters.underlyingErrorDomain
    ]

    /// Filter out the standard parameters.
    ///
    private static func filterStandardPixelParameters(from parameters: [String: String]) -> [String: String] {
        parameters.filter { element in
            !standardPixelParameters.contains(element.key)
        }
    }

    static var pixelPlatformPrefix: String {
#if os(macOS)
        return "m_mac_"
#else
        // Intentionally left blank for now because PixelKit currently doesn't support
        // other platforms, but if we decide to implement another platform this'll fail
        // and indicate that we need a value here.
#endif
    }

    func expectedParameters(for event: PixelKitEventV2) -> [String: String] {
        var expectedParameters = [String: String]()

        if let error = event.error {
            let nsError = error as NSError
            expectedParameters[PixelKit.Parameters.errorCode] = "\(nsError.code)"
            expectedParameters[PixelKit.Parameters.errorDomain] = nsError.domain

            if let underlyingError = (error as? PixelKitEventErrorDetails)?.underlyingError {
                let underlyingNSError = underlyingError as NSError
                expectedParameters[PixelKit.Parameters.underlyingErrorCode] = "\(underlyingNSError.code)"
                expectedParameters[PixelKit.Parameters.underlyingErrorDomain] = underlyingNSError.domain
            }
        }

        return expectedParameters
    }

    // MARK: - Misc Convenience

    private var userDefaults: UserDefaults {
        UserDefaults(suiteName: "testing_\(UUID().uuidString)")!
    }

    // MARK: - Pixel Firing Expectations

    /// Provides some snapshot of a fired pixel so that external libraries can validate all the expected info is included.
    ///
    /// This method also checks that there is internal consistency in the expected fields.
    ///
    func verifyThat(_ event: PixelKitEventV2, meets expectations: PixelFireExpectations, file: StaticString, line: UInt) {

        let expectedPixelName = Self.pixelPlatformPrefix + event.name
        let expectedParameters = expectedParameters(for: event)
        let callbackExecutedExpectation = expectation(description: "The PixelKit callback has been executed")

        PixelKit.setUp(dryRun: false,
                       appVersion: "1.0.5",
                       source: "test-app",
                       defaultHeaders: [:],
                       log: .disabled,
                       defaults: userDefaults) { firedPixelName, _, firedParameters, _, _, completion in
            callbackExecutedExpectation.fulfill()

            let firedParameters = Self.filterStandardPixelParameters(from: firedParameters)

            // Internal validations

            XCTAssertEqual(firedPixelName, expectedPixelName, file: file, line: line)
            XCTAssertEqual(firedParameters, expectedParameters, file: file, line: line)

            // Expectations

            XCTAssertEqual(firedPixelName, expectations.pixelName)

            if let error = expectations.error {
                let nsError = error as NSError
                XCTAssertEqual(firedParameters[PixelKit.Parameters.errorCode], String(nsError.code), file: file, line: line)
                XCTAssertEqual(firedParameters[PixelKit.Parameters.errorDomain], nsError.domain, file: file, line: line)
            }

            if let underlyingError = expectations.underlyingError {
                let nsError = underlyingError as NSError
                XCTAssertEqual(firedParameters[PixelKit.Parameters.underlyingErrorCode], String(nsError.code), file: file, line: line)
                XCTAssertEqual(firedParameters[PixelKit.Parameters.underlyingErrorDomain], nsError.domain, file: file, line: line)
            }

            completion(true, nil)
        }

        PixelKit.fire(event)
        waitForExpectations(timeout: 0.1)
    }
}
