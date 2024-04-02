//
//  AttributionOriginFileProviderTests.swift
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

final class AttributionOriginFileProviderTests: XCTestCase {
    private var sut: AttributionOriginFileProvider!

    func testWhenFileAndValueExistThenReturnOriginValue() {
        // GIVEN
        sut = AttributionOriginFileProvider(bundle: .test)

        // WHEN
        let result = sut.origin

        // THEN
        XCTAssertEqual(result, "app_search")
    }

    func testWhenFileDoesNotExistThenReturnNil() {
        // GIVEN
        sut = AttributionOriginFileProvider(resourceName: #function, bundle: .test)

        // WHEN
        let result = sut.origin

        // THEN
        XCTAssertNil(result)
    }

    func testWhenFileExistAndIsEmptyThenReturnNil() {
        // GIVEN
        sut = AttributionOriginFileProvider(resourceName: "Origin-empty", bundle: .test)

        // WHEN
        let result = sut.origin

        // THEN
        XCTAssertNil(result)
    }
}

private extension Bundle {
    static let test = Bundle(for: AttributionOriginFileProviderTests.self)
}
