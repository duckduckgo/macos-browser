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
    /// This is useful to support filtering these parameters out if needed.
    private static var standardPixelParameters = [
        PixelKit.Parameters.appVersion,
        PixelKit.Parameters.pixelSource,
        PixelKit.Parameters.test
    ]

    /// List of errror pixel parameters
    private static var errorPixelParameters = [
        PixelKit.Parameters.errorCode,
        PixelKit.Parameters.errorDomain
    ]

    /// List of underlying error pixel parameters
    private static var underlyingErrorPixelParameters = [
        PixelKit.Parameters.underlyingErrorCode,
        PixelKit.Parameters.underlyingErrorDomain
    ]

    /// Filter out the standard parameters.
    private static func filterStandardPixelParameters(from parameters: [String: String]) -> [String: String] {
        parameters.filter { element in
            !standardPixelParameters.contains(element.key)
        }
    }

    static var pixelPlatformPrefix: String {
#if os(macOS)
        return "m_mac_"
#elseif os(iOS)
        return "m_"
#endif
    }

    /// These parameters are known to be expected just based on the event definition.
    ///
    /// They're not a complete list of parameters for the event, as the fire call may contain extra information
    /// that results in additional parameters.  Ideally we want most (if not all) that information to eventually
    /// make part of the pixel definition.
    func knownExpectedParameters(for event: PixelKitEventV2) -> [String: String] {
        var expectedParameters = [String: String]()

        if let error = event.error {
            let nsError = error as NSError
            expectedParameters[PixelKit.Parameters.errorCode] = "\(nsError.code)"
            expectedParameters[PixelKit.Parameters.errorDomain] = nsError.domain

            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                expectedParameters[PixelKit.Parameters.underlyingErrorCode] = "\(underlyingError.code)"
                expectedParameters[PixelKit.Parameters.underlyingErrorDomain] = underlyingError.domain
            }
        }

        return expectedParameters
    }

    // MARK: - Misc Convenience

    private var userDefaults: UserDefaults {
        UserDefaults(suiteName: "testing_\(UUID().uuidString)")!
    }

    // MARK: - Pixel Firing Expectations

    func fire(_ event: PixelKitEventV2, frequency: PixelKit.Frequency, and expectations: PixelFireExpectations, file: StaticString, line: UInt) {
        verifyThat(event, frequency: frequency, meets: expectations, file: file, line: line)
    }

    /// Provides some snapshot of a fired pixel so that external libraries can validate all the expected info is included.
    ///
    /// This method also checks that there is internal consistency in the expected fields.
    func verifyThat(_ event: PixelKitEventV2,
                    frequency: PixelKit.Frequency,
                    meets expectations: PixelFireExpectations,
                    file: StaticString,
                    line: UInt) {

        let expectedPixelName = event.name.hasPrefix(Self.pixelPlatformPrefix) ? event.name : Self.pixelPlatformPrefix + event.name
        let knownExpectedParameters = knownExpectedParameters(for: event)
        let callbackExecutedExpectation = expectation(description: "The PixelKit callback has been executed")

        // Ensure PixelKit is torn down before setting it back up, avoiding unit test race conditions:
        PixelKit.tearDown()

        PixelKit.setUp(dryRun: false,
                       appVersion: "1.0.5",
                       source: "test-app",
                       defaultHeaders: [:],
                       defaults: userDefaults) { firedPixelName, _, firedParameters, _, _, completion in
            callbackExecutedExpectation.fulfill()

            let firedParameters = Self.filterStandardPixelParameters(from: firedParameters)

            // Internal validations

            XCTAssertEqual(firedPixelName, expectedPixelName, file: file, line: line)

            XCTAssertTrue(knownExpectedParameters.allSatisfy { (key, value) in
                firedParameters[key] == value
            })

            // Expectations
            XCTAssertEqual(firedPixelName, expectations.pixelName)
            XCTAssertEqual(firedParameters, expectations.parameters)

            completion(true, nil)
        }

        PixelKit.fire(event, frequency: frequency)
        waitForExpectations(timeout: 0.1)
    }
}
