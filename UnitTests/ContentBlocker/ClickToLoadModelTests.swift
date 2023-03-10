//
//  ClickToLoadModelTests.swift
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

import XCTest
import TrackerRadarKit
import BrowserServicesKit
@testable import DuckDuckGo_Privacy_Browser

class ClickToLoadModelTests: XCTestCase {

    func testClickToLoadModelInagesArePresent() {

        let nmodelImages = ClickToLoadModel.getImage
        let expectedImages = [
            "dax.png",
            "loading_light.svg",
            "loading_dark.svg",
            "blocked_facebook_logo.svg",
            "blocked_group.svg",
            "blocked_page.svg",
            "blocked_post.svg",
            "blocked_video.svg"
        ]

        for (image) in expectedImages {
            XCTAssertNotNil(nmodelImages[image], "Error: missing ClickToLoadModel image: " + image)
        }
    }

}
