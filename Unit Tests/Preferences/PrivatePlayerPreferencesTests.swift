//
//  PrivatePlayerPreferencesTests.swift
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

final class PrivatePlayerPreferencesTests: XCTestCase {

    func testWhenInitializedThenItLoadsPersistedValues() throws {
        var model = PrivatePlayerPreferences(
            persistor: PrivatePlayerPreferencesPersistorMock(
                privatePlayerMode: .alwaysAsk,
                youtubeOverlayInteracted: false
            )
        )

        XCTAssertEqual(model.privatePlayerMode, .alwaysAsk)
        XCTAssertEqual(model.youtubeOverlayInteracted, false)

        model = PrivatePlayerPreferences(
            persistor: PrivatePlayerPreferencesPersistorMock(
                privatePlayerMode: .enabled,
                youtubeOverlayInteracted: true
            )
        )

        XCTAssertEqual(model.privatePlayerMode, .enabled)
        XCTAssertEqual(model.youtubeOverlayInteracted, true)
    }

    func testWhenPropertiesAreUpdatedThenPersistedValuesAreUpdated() throws {
        let persistor = PrivatePlayerPreferencesPersistorMock()
        let model = PrivatePlayerPreferences(persistor: persistor)

        model.privatePlayerMode = .enabled
        XCTAssertEqual(persistor.privatePlayerMode, .enabled)
        model.privatePlayerMode = .disabled
        XCTAssertEqual(persistor.privatePlayerMode, .disabled)

        model.youtubeOverlayInteracted = true
        XCTAssertEqual(persistor.youtubeOverlayInteracted, true)
        model.youtubeOverlayInteracted = false
        XCTAssertEqual(persistor.youtubeOverlayInteracted, false)
    }
}
