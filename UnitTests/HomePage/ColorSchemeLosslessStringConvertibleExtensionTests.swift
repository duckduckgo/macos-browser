//
//  ColorSchemeLosslessStringConvertibleExtensionTests.swift
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

@testable import DuckDuckGo_Privacy_Browser
import Foundation
import SwiftUI
import XCTest

final class ColorSchemeLosslessStringConvertibleExtensionTests: XCTestCase {

    func testColorSchemeInitWithDescription() {
        XCTAssertEqual(ColorScheme("light"), ColorScheme.light)
        XCTAssertEqual(ColorScheme("dark"), ColorScheme.dark)
        XCTAssertNil(ColorScheme("Light"))
        XCTAssertNil(ColorScheme("DARK"))
        XCTAssertNil(ColorScheme("boo"))
    }

    func testDescription() {
        XCTAssertEqual(ColorScheme.light.description, "light")
        XCTAssertEqual(ColorScheme.dark.description, "dark")
    }
}
