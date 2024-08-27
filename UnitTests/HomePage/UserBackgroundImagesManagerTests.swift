//
//  UserBackgroundImagesManagerTests.swift
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
import PixelKit
import XCTest

final class UserBackgroundImagesManagerTests: XCTestCase {

    var manager: UserBackgroundImagesManager!
    var storageLocation: URL!
    var imageProcessor: CapturingImageProcessor!
    var sendPixelEvents: [PixelKitEvent] = []

    override func setUp() async throws {
        sendPixelEvents = []
        storageLocation = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        imageProcessor = CapturingImageProcessor()

        manager = UserBackgroundImagesManager(
            maximumNumberOfImages: 4,
            applicationSupportDirectory: storageLocation,
            imageProcessor: imageProcessor,
            sendPixel: { [weak self] in self?.sendPixelEvents.append($0) }
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: storageLocation)
    }

    func testWhenManagerIsInitializedSucessfullyThenPixelIsNotSent() {
        
    }
}
