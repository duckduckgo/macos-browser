//
//  ValidatePixel.swift
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
import PixelKit
import XCTest

public final class PixelRequestValidator {
    public init() {}

    public func validateBasicPixelParams(
        expectedAppVersion: String,
        expectedUserAgent: String,
        requestParameters parameters: [String: String],
        requestHeaders headers: [String: String]) {

        XCTAssertEqual(parameters[PixelKit.Parameters.test], "1")
        XCTAssertEqual(parameters[PixelKit.Parameters.appVersion], expectedAppVersion)

        XCTAssertEqual(headers[PixelKit.Header.userAgent], expectedUserAgent)
        XCTAssertEqual(headers[PixelKit.Header.acceptEncoding], "gzip;q=1.0, compress;q=0.5")
        XCTAssertNotNil(headers[PixelKit.Header.acceptLanguage])
        XCTAssertNotNil(headers[PixelKit.Header.moreInfo], PixelKit.duckDuckGoMorePrivacyInfo.absoluteString)
    }

    public func validateDebugPixelParams(
        expectedError: Error?,
        requestParameters parameters: [String: String]) {

        if let error = expectedError as? NSError {
            XCTAssertEqual(parameters[PixelKit.Parameters.errorCode], "\(error.code)")
            XCTAssertEqual(parameters[PixelKit.Parameters.errorDomain], error.domain)
        }
    }
}
