//
//  SubscriptionAttributionPixelHandlerTests.swift
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
import PixelKit
@testable import DuckDuckGo_Privacy_Browser

final class SubscriptionAttributionPixelHandlerTests: XCTestCase {
    private var sut: PrivacyProSubscriptionAttributionPixelHandler!
    private var capturedParams: PixelCapturedParameters!
    private var fireRequest: GenericAttributionPixelHandler.FireRequest!
    private var mockAttributionOriginProvider: MockAttributionOriginProvider!

    override func setUpWithError() throws {
        try super.setUpWithError()
        capturedParams = PixelCapturedParameters()
        fireRequest = { event, frequency, headers, parameters, error, reservedCharacters, includeAppVersion, onComplete in
            self.capturedParams.event = event
            self.capturedParams.frequency = frequency
            self.capturedParams.headers = headers
            self.capturedParams.parameters = parameters
            self.capturedParams.error = error
            self.capturedParams.reservedCharacters = reservedCharacters
            self.capturedParams.includeAppVersion = includeAppVersion
            self.capturedParams.onComplete = onComplete
        }
        mockAttributionOriginProvider = MockAttributionOriginProvider()
    }

    override func tearDownWithError() throws {
        capturedParams = nil
        fireRequest = nil
        mockAttributionOriginProvider = nil
        sut = nil
        try super.tearDownWithError()
    }

    func testWhenPixelFiresThenNameIsSetToM_Mac_Subscribe() {
        // GIVEN
        let decoratedPixelHandler = GenericAttributionPixelHandler(originProvider: mockAttributionOriginProvider, fireRequest: fireRequest, locale: .current)
        sut = PrivacyProSubscriptionAttributionPixelHandler(attributionPixelHandler: decoratedPixelHandler, originStore: mockAttributionOriginProvider)

        // WHEN
        sut.fireSuccessfulSubscriptionAttributionPixel()

        // THEN
        XCTAssertEqual(capturedParams.event?.name, "m_mac_subscribe")
    }

    func testwhenPixelFireThenOriginIsDeletedFromStorage() {
        let origin = "test"
        mockAttributionOriginProvider.origin = origin
        let decoratedPixelHandler = GenericAttributionPixelHandler(originProvider: mockAttributionOriginProvider, fireRequest: fireRequest, locale: .current)
        sut = PrivacyProSubscriptionAttributionPixelHandler(attributionPixelHandler: decoratedPixelHandler, originStore: mockAttributionOriginProvider)
        XCTAssertEqual(mockAttributionOriginProvider.origin, origin)

        // WHEN
        sut.fireSuccessfulSubscriptionAttributionPixel()

        XCTAssertNil(mockAttributionOriginProvider.origin)
    }

    func testWhenPixelFiresThenLanguageCodeIsSet() {
        // GIVEN
        let locale = Locale(identifier: "hu-HU")
        let decoratedPixelHandler = GenericAttributionPixelHandler(originProvider: mockAttributionOriginProvider, fireRequest: fireRequest, locale: locale)
        sut = PrivacyProSubscriptionAttributionPixelHandler(attributionPixelHandler: decoratedPixelHandler, originStore: mockAttributionOriginProvider)

        // WHEN
        sut.fireSuccessfulSubscriptionAttributionPixel()

        // THEN
        XCTAssertEqual(capturedParams?.parameters?[GenericAttributionPixelHandler.Parameters.locale], "hu-HU")
    }

    func testWhenPixelFiresAndOriginIsNotNilThenOriginIsSet() {
        // GIVEN
        let origin = "app_search"
        let locale = Locale(identifier: "en-US")
        let originProvider = MockAttributionOriginProvider(origin: origin)
        let decoratedPixelHandler = GenericAttributionPixelHandler(originProvider: originProvider, fireRequest: fireRequest, locale: locale)
        sut = PrivacyProSubscriptionAttributionPixelHandler(attributionPixelHandler: decoratedPixelHandler, originStore: originProvider)

        // WHEN
        sut.fireSuccessfulSubscriptionAttributionPixel()

        // THEN
        XCTAssertEqual(capturedParams?.parameters?[GenericAttributionPixelHandler.Parameters.origin], origin)
        XCTAssertEqual(capturedParams?.parameters?[GenericAttributionPixelHandler.Parameters.locale], "en-US")
    }

    func testWhenPixelFiresAndOriginIsNilThenOnlyLocaleIsSet() {
        // GIVEN
        let origin: String? = nil
        let locale = Locale(identifier: "en-US")
        let originProvider = MockAttributionOriginProvider(origin: origin)
        let decoratedPixelHandler = GenericAttributionPixelHandler(originProvider: originProvider, fireRequest: fireRequest, locale: locale)
        sut = PrivacyProSubscriptionAttributionPixelHandler(attributionPixelHandler: decoratedPixelHandler, originStore: originProvider)

        // WHEN
        sut.fireSuccessfulSubscriptionAttributionPixel()

        // THEN
        XCTAssertNil(capturedParams?.parameters?[GenericAttributionPixelHandler.Parameters.origin])
        XCTAssertEqual(capturedParams?.parameters?[GenericAttributionPixelHandler.Parameters.locale], "en-US")
    }

    func testWhenPixelFiresThenAddAppVersionIsTrueAndFrequencyIsStandard() {
        // GIVEN
        let decoratedPixelHandler = GenericAttributionPixelHandler(originProvider: mockAttributionOriginProvider, fireRequest: fireRequest, locale: .current)
        sut = PrivacyProSubscriptionAttributionPixelHandler(attributionPixelHandler: decoratedPixelHandler, originStore: mockAttributionOriginProvider)

        // WHEN
        sut.fireSuccessfulSubscriptionAttributionPixel()

        // THEN
        XCTAssertEqual(capturedParams.includeAppVersion, true)
        XCTAssertEqual(capturedParams.frequency, .standard)
    }
}
