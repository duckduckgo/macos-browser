//
//  DuckPlayerPreferencesTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
@testable import DuckDuckGo_Privacy_Browser

final class DuckPlayerPreferencesTests: XCTestCase {

    func testWhenInitializedThenItLoadsPersistedValues() throws {
        var model = DuckPlayerPreferences(
            persistor: DuckPlayerPreferencesPersistorMock(
                duckPlayerMode: .alwaysAsk,
                youtubeOverlayInteracted: false
            )
        )

        XCTAssertEqual(model.duckPlayerMode, .alwaysAsk)
        XCTAssertEqual(model.youtubeOverlayInteracted, false)

        model = DuckPlayerPreferences(
            persistor: DuckPlayerPreferencesPersistorMock(
                duckPlayerMode: .enabled,
                youtubeOverlayInteracted: true
            )
        )

        XCTAssertEqual(model.duckPlayerMode, .enabled)
        XCTAssertEqual(model.youtubeOverlayInteracted, true)
    }

    func testWhenPropertiesAreUpdatedThenPersistedValuesAreUpdated() throws {
        let persistor = DuckPlayerPreferencesPersistorMock()
        let model = DuckPlayerPreferences(persistor: persistor)

        model.duckPlayerMode = .enabled
        XCTAssertEqual(persistor.duckPlayerMode, .enabled)
        model.duckPlayerMode = .disabled
        XCTAssertEqual(persistor.duckPlayerMode, .disabled)

        model.youtubeOverlayInteracted = true
        XCTAssertEqual(persistor.youtubeOverlayInteracted, true)
        model.youtubeOverlayInteracted = false
        XCTAssertEqual(persistor.youtubeOverlayInteracted, false)
    }
}
