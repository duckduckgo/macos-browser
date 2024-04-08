//
//  InstallationAttributionPixelHandlerTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

final class InstallationAttributionPixelHandlerTests: XCTestCase {
    private var sut: InstallationAttributionPixelHandler!
    private var capturedParams: CapturedParameters!
    private var fireRequest: InstallationAttributionPixelHandler.FireRequest!

    override func setUpWithError() throws {
        try super.setUpWithError()
        capturedParams = CapturedParameters()
        fireRequest = { event, repetition, parameters, reservedCharacters, includeAppVersion, onComplete in
            self.capturedParams.event = event
            self.capturedParams.repetition = repetition
            self.capturedParams.parameters = parameters
            self.capturedParams.reservedCharacters = reservedCharacters
            self.capturedParams.includeAppVersion = includeAppVersion
            self.capturedParams.onComplete = onComplete
        }
    }

    override func tearDownWithError() throws {
        capturedParams = nil
        fireRequest = nil
        sut = nil
        try super.tearDownWithError()
    }

    func testWhenPixelFiresThenNameIsSetToM_Mac_Install() {
        // GIVEN
        sut = .init(fireRequest: fireRequest, originProvider: MockAttributionOriginProvider(), locale: .current)

        // WHEN
        sut.fireInstallationAttributionPixel()

        // THEN
        XCTAssertEqual(capturedParams.event?.name, "m_mac_install")
    }

    func testWhenPixelFiresThenLanguageCodeIsSet() {
        // GIVEN
        let locale = Locale(identifier: "hu-HU")
        sut = .init(fireRequest: fireRequest, originProvider: MockAttributionOriginProvider(), locale: locale)

        // WHEN
        sut.fireInstallationAttributionPixel()

        // THEN
        XCTAssertEqual(capturedParams?.parameters?[InstallationAttributionPixelHandler.Parameters.locale], "hu-HU")
    }

    func testWhenPixelFiresAndOriginIsNotNilThenOriginIsSet() {
        // GIVEN
        let origin = "app_search"
        let locale = Locale(identifier: "en-US")
        let originProvider = MockAttributionOriginProvider(origin: origin)
        sut = .init(fireRequest: fireRequest, originProvider: originProvider, locale: locale)

        // WHEN
        sut.fireInstallationAttributionPixel()

        // THEN
        XCTAssertEqual(capturedParams?.parameters?[InstallationAttributionPixelHandler.Parameters.origin], origin)
        XCTAssertEqual(capturedParams?.parameters?[InstallationAttributionPixelHandler.Parameters.locale], "en-US")
    }

    func testWhenPixelFiresAndOriginIsNilThenOnlyLocaleIsSet() {
        // GIVEN
        let origin: String? = nil
        let locale = Locale(identifier: "en-US")
        let originProvider = MockAttributionOriginProvider(origin: origin)
        sut = .init(fireRequest: fireRequest, originProvider: originProvider, locale: locale)

        // WHEN
        sut.fireInstallationAttributionPixel()

        // THEN
        XCTAssertNil(capturedParams?.parameters?[InstallationAttributionPixelHandler.Parameters.origin])
        XCTAssertEqual(capturedParams?.parameters?[InstallationAttributionPixelHandler.Parameters.locale], "en-US")
    }

    func testWhenPixelFiresThenAddAppVersionIsTrueAndRepetitionIsInitial() {
        // GIVEN
        sut = .init(fireRequest: fireRequest, originProvider: MockAttributionOriginProvider(), locale: .current)

        // WHEN
        sut.fireInstallationAttributionPixel()

        // THEN
        XCTAssertEqual(capturedParams.includeAppVersion, true)
        XCTAssertEqual(capturedParams.repetition, .initial)
    }
}

extension InstallationAttributionPixelHandlerTests {

    struct CapturedParameters {
        var event: Pixel.Event?
        var repetition: Pixel.Event.Repetition = .repetitive
        var parameters: [String: String]?
        var reservedCharacters: CharacterSet?
        var includeAppVersion: Bool?
        var onComplete: (Error?) -> Void = { _ in }
    }

}
