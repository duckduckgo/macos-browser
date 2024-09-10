//
//  UserBackgroundImageTests.swift
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
import XCTest

final class UserBackgroundImageTests: XCTestCase {

    func testMemberwiseInitializer() {
        let image = UserBackgroundImage(fileName: "abc.jpg", colorScheme: .dark)
        XCTAssertEqual(image.fileName, "abc.jpg")
        XCTAssertEqual(image.colorScheme, .dark)
    }

    func testDescription() {
        let image = UserBackgroundImage(fileName: "abc.jpg", colorScheme: .dark)
        XCTAssertEqual(image.description, "abc.jpg|dark")
    }

    func testDescriptionInitializer() throws {
        var image = try XCTUnwrap(UserBackgroundImage("abc.jpg|dark"))
        XCTAssertEqual(image.fileName, "abc.jpg")
        XCTAssertEqual(image.colorScheme, .dark)

        image = try XCTUnwrap(UserBackgroundImage("abc|def.jpg|dark"))
        XCTAssertEqual(image.fileName, "abc|def.jpg")
        XCTAssertEqual(image.colorScheme, .dark)

        image = try XCTUnwrap(UserBackgroundImage("abc|d||||||||ef.jpg|light"))
        XCTAssertEqual(image.fileName, "abc|d||||||||ef.jpg")
        XCTAssertEqual(image.colorScheme, .light)

        image = try XCTUnwrap(UserBackgroundImage("image|light"))
        XCTAssertEqual(image.fileName, "image")
        XCTAssertEqual(image.colorScheme, .light)

        XCTAssertNil(UserBackgroundImage(""))
        XCTAssertNil(UserBackgroundImage("|"))
        XCTAssertNil(UserBackgroundImage("|dark"))
        XCTAssertNil(UserBackgroundImage("dark"))
        XCTAssertNil(UserBackgroundImage("example.jpg"))
        XCTAssertNil(UserBackgroundImage("example.jpg|"))
        XCTAssertNil(UserBackgroundImage("example.jpg|nope"))
        XCTAssertNil(UserBackgroundImage("example.jpg;light"))
    }
}
