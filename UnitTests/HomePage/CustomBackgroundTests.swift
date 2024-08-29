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
        XCTAssertNil(CustomBackground.solidColor(.black).gradient)
        XCTAssertNil(CustomBackground.illustration(.illustration03).gradient)
        XCTAssertNil(CustomBackground.userImage(.init(fileName: "abc.jpg", colorScheme: .light)).gradient)
    }

    func testSolidColor() {
        XCTAssertEqual(CustomBackground.solidColor(.black).solidColor, .black)
        XCTAssertEqual(CustomBackground.solidColor(.darkPink).solidColor, .darkPink)
        XCTAssertNil(CustomBackground.gradient(.gradient03).solidColor)
        XCTAssertNil(CustomBackground.illustration(.illustration03).solidColor)
        XCTAssertNil(CustomBackground.userImage(.init(fileName: "abc.jpg", colorScheme: .light)).solidColor)
    }

    func testIllustration() {
        XCTAssertEqual(CustomBackground.illustration(.illustration01).illustration, .illustration01)
        XCTAssertEqual(CustomBackground.illustration(.illustration03).illustration, .illustration03)
        XCTAssertNil(CustomBackground.gradient(.gradient03).illustration)
        XCTAssertNil(CustomBackground.solidColor(.lightBlue).illustration)
        XCTAssertNil(CustomBackground.userImage(.init(fileName: "abc.jpg", colorScheme: .light)).illustration)
    }

    func testUserBackgroundImage() {
        let userImage1 = UserBackgroundImage(fileName: "abc.jpg", colorScheme: .light)
        let userImage2 = UserBackgroundImage(fileName: "example.jpg", colorScheme: .dark)
        XCTAssertEqual(CustomBackground.userImage(userImage1).userBackgroundImage, userImage1)
        XCTAssertEqual(CustomBackground.userImage(userImage2).userBackgroundImage, userImage2)
        XCTAssertNil(CustomBackground.gradient(.gradient03).userBackgroundImage)
        XCTAssertNil(CustomBackground.solidColor(.lightBlue).userBackgroundImage)
        XCTAssertNil(CustomBackground.illustration(.illustration04).userBackgroundImage)
    }

    func testColorScheme() {
        XCTAssertEqual(CustomBackground.gradient(.gradient03).colorScheme, GradientBackground.gradient03.colorScheme)
        XCTAssertEqual(CustomBackground.solidColor(.darkBlue).colorScheme, SolidColorBackground.darkBlue.colorScheme)
        XCTAssertEqual(CustomBackground.illustration(.illustration01).colorScheme, IllustrationBackground.illustration01.colorScheme)
        XCTAssertEqual(CustomBackground.userImage(.init(fileName: "abc.jpg", colorScheme: .dark)).colorScheme, .dark)
    }

    func testDescription() {
        XCTAssertEqual(CustomBackground.gradient(.gradient01).description, "gradient|gradient01")
        XCTAssertEqual(CustomBackground.solidColor(.darkPurple).description, "solidColor|darkPurple")
        XCTAssertEqual(CustomBackground.illustration(.illustration06).description, "illustration|illustration06")

        let image = UserBackgroundImage(fileName: "abc.jpg", colorScheme: .dark)
        XCTAssertEqual(CustomBackground.userImage(image).description, "userImage|\(image.description)")
    }

    func testDescriptionInitializer() {
        XCTAssertEqual(CustomBackground("gradient|gradient03"), .gradient(.gradient03))
        XCTAssertEqual(CustomBackground("solidColor|lightOrange"), .solidColor(.lightOrange))
        XCTAssertEqual(CustomBackground("illustration|illustration04"), .illustration(.illustration04))

        XCTAssertEqual(CustomBackground("userImage|abc.jpg|dark"), .userImage(.init(fileName: "abc.jpg", colorScheme: .dark)))
        XCTAssertEqual(CustomBackground("userImage|abc|def.jpg|light"), .userImage(.init(fileName: "abc|def.jpg", colorScheme: .light)))
        XCTAssertEqual(CustomBackground("userImage||abc.jpg|dark"), .userImage(.init(fileName: "|abc.jpg", colorScheme: .dark)))

        XCTAssertNil(CustomBackground("gradient|darkPurple"))
        XCTAssertNil(CustomBackground("gradient|gradient400"))
        XCTAssertNil(CustomBackground("gradient|"))
        XCTAssertNil(CustomBackground("gradient03"))

        XCTAssertNil(CustomBackground("solidColor"))
        XCTAssertNil(CustomBackground("solidColor|lightBlack"))
        XCTAssertNil(CustomBackground("solidColor|illustration01"))
        XCTAssertNil(CustomBackground("darkBlue"))

        XCTAssertNil(CustomBackground("illustration|illustration98"))
        XCTAssertNil(CustomBackground("illustration"))
        XCTAssertNil(CustomBackground("illustration|gradient02"))
        XCTAssertNil(CustomBackground("illustration04"))

        XCTAssertNil(CustomBackground("userImage"))
        XCTAssertNil(CustomBackground("userImage|"))
        XCTAssertNil(CustomBackground("userImage|dark"))
        XCTAssertNil(CustomBackground("userImage|illustration04"))
        XCTAssertNil(CustomBackground("abc.jpg|dark"))
    }
}
