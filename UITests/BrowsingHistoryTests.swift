//
//	BrowsingHistoryTests.swift
//
//	Copyright © 2024 DuckDuckGo. All rights reserved.
//
//	Licensed under the Apache License, Version 2.0 (the "License");
//	you may not use this file except in compliance with the License.
//	You may obtain a copy of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
//	Unless required by applicable law or agreed to in writing, software
//	distributed under the License is distributed on an "AS IS" BASIS,
//	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//	See the License for the specific language governing permissions and
//	limitations under the License.
//

import XCTest

class BrowsingHistoryTests: XCTestCase {
	let app = XCUIApplication()
	let timeout = 0.3

	override class func setUp() {

	}

	override class func tearDown() {

	}

	override func setUpWithError() throws {
		continueAfterFailure = false
		app.launch()
		app.typeKey("w", modifierFlags: [.command, .option, .shift]) // Let's enforce a single window
		app.typeKey("n", modifierFlags: .command)
	}

	func test_failingTest() throws {
		XCTFail("should always fail.")
	}
}
