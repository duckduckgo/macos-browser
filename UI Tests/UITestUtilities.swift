//
//  UITestUtilities.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

extension XCUIElement {
    /*
     Works around an issue where XCUITest sometimes identifies elements as
     non-hittable, which makes the built-in hover() and click() methods fail.
     See https://newbedev.com/xcode-ui-test-ui-testing-failure-failed-to-scroll-to-visible-by-ax-action-when-tap-on-search-field-cancel-button
     */
    func forceHoverElement() {
        if self.isHittable {
            self.hover()
        } else {
            let coordinate: XCUICoordinate = self.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.0))
            coordinate.hover()
        }
    }
    func forceClickElement() {
        if self.isHittable {
            self.click()
        } else {
            let coordinate: XCUICoordinate = self.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: 0.0))
            coordinate.click()
        }
    }
}

internal class DDGUITestCase: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        let app = XCUIApplication()
        app.launchEnvironment = ["isUITest": "true"]
        app.launch()
    }
}
