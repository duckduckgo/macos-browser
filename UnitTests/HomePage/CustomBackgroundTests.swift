//
//  CustomBackgroundTests.swift
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

final class CustomBackgroundTests: XCTestCase {

    func testGradient() {
        XCTAssertEqual(CustomBackground.gradient(.gradient01).gradient, .gradient01)
        XCTAssertEqual(CustomBackground.gradient(.gradient05).gradient, .gradient05)
        XCTAssertNil(CustomBackground.solidColor(.color01).gradient)
        XCTAssertNil(CustomBackground.userImage(.init(fileName: "abc.jpg", colorScheme: .light)).gradient)
    }

    func testSolidColor() {
        XCTAssertEqual(CustomBackground.solidColor(.color01).solidColor, .color01)
        XCTAssertEqual(CustomBackground.solidColor(.color13).solidColor, .color13)
        XCTAssertEqual(CustomBackground.solidColor(.init(color: .green)).solidColor, .init(color: .green))
        XCTAssertNil(CustomBackground.gradient(.gradient03).solidColor)
        XCTAssertNil(CustomBackground.userImage(.init(fileName: "abc.jpg", colorScheme: .light)).solidColor)
    }

    func testUserBackgroundImage() {
        let userImage1 = UserBackgroundImage(fileName: "abc.jpg", colorScheme: .light)
        let userImage2 = UserBackgroundImage(fileName: "example.jpg", colorScheme: .dark)
        XCTAssertEqual(CustomBackground.userImage(userImage1).userBackgroundImage, userImage1)
        XCTAssertEqual(CustomBackground.userImage(userImage2).userBackgroundImage, userImage2)
        XCTAssertNil(CustomBackground.gradient(.gradient03).userBackgroundImage)
        XCTAssertNil(CustomBackground.solidColor(.color14).userBackgroundImage)
    }

    func testColorScheme() {
        XCTAssertEqual(CustomBackground.gradient(.gradient03).colorScheme, GradientBackground.gradient03.colorScheme)
        XCTAssertEqual(CustomBackground.solidColor(.color04).colorScheme, SolidColorBackground.color04.colorScheme)
        XCTAssertEqual(CustomBackground.userImage(.init(fileName: "abc.jpg", colorScheme: .dark)).colorScheme, .dark)
    }

    func testDescription() {
        XCTAssertEqual(CustomBackground.gradient(.gradient01).description, "gradient|gradient01")
        XCTAssertEqual(CustomBackground.solidColor(.color04).description, "solidColor|color04")

        let image = UserBackgroundImage(fileName: "abc.jpg", colorScheme: .dark)
        XCTAssertEqual(CustomBackground.userImage(image).description, "userImage|\(image.description)")
    }

    func testDescriptionInitializer() {
        XCTAssertEqual(CustomBackground("gradient|gradient03"), .gradient(.gradient03))
        XCTAssertEqual(CustomBackground("gradient|gradient02.01"), .gradient(.gradient0201))
        XCTAssertEqual(CustomBackground("solidColor|color02"), .solidColor(.color02))
        XCTAssertEqual(CustomBackground("solidColor|#FEFC4B"), .solidColor(.init(color: NSColor(hex: "#FEFC4B")!)))

        XCTAssertEqual(CustomBackground("userImage|abc.jpg|dark"), .userImage(.init(fileName: "abc.jpg", colorScheme: .dark)))
        XCTAssertEqual(CustomBackground("userImage|abc|def.jpg|light"), .userImage(.init(fileName: "abc|def.jpg", colorScheme: .light)))
        XCTAssertEqual(CustomBackground("userImage||abc.jpg|dark"), .userImage(.init(fileName: "|abc.jpg", colorScheme: .dark)))

        XCTAssertNil(CustomBackground("gradient|darkPurple"))
        XCTAssertNil(CustomBackground("gradient|gradient400"))
        XCTAssertNil(CustomBackground("gradient|"))
        XCTAssertNil(CustomBackground("gradient03"))

        XCTAssertNil(CustomBackground("solidColor"))
        XCTAssertNil(CustomBackground("solidColor|color2100"))
        XCTAssertNil(CustomBackground("solidColor|illustration01"))
        XCTAssertNil(CustomBackground("darkBlue"))

        XCTAssertNil(CustomBackground("userImage"))
        XCTAssertNil(CustomBackground("userImage|"))
        XCTAssertNil(CustomBackground("userImage|dark"))
        XCTAssertNil(CustomBackground("userImage|illustration04"))
        XCTAssertNil(CustomBackground("abc.jpg|dark"))
    }
}
