//
//  PrivacyIconViewModelTests.swift
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
@testable import DuckDuckGo_Privacy_Browser

class PrivacyIconViewModelTests: XCTestCase {

    override class func tearDown() {
        NSApp.appearance = nil
    }

    func testWhenIconsAccessed_ThenNoException() throws {
        var letterImages: [NSAppearance.Name: [Character: CGImage]] = [:]
        var blankTrackerImages: [NSAppearance.Name: CGImage] = [:]
        var shadowTrackerImages: [NSAppearance.Name: CGImage] = [:]
        var logos: [NSAppearance.Name: [TrackerNetwork: CGImage]] = [:]

        for appearanceName: NSAppearance.Name in [.aqua, .darkAqua] {
            NSApp.appearance = .init(named: appearanceName)!

            XCTAssertNil(PrivacyIconViewModel.logo(for: "")) // shouldn‘t assert
            for tracker in TrackerNetwork.allCases {
                let logo = PrivacyIconViewModel.logo(for: tracker.rawValue)
                let feedLogo = HomePage.Models.RecentlyVisitedSiteModel.feedImage(for: tracker)?
                    .cgImage(forProposedRect: nil, context: .current, hints: nil)

                XCTAssertNotNil(logo)
                if case .windows = tracker {
                    XCTAssertNil(feedLogo, "\(tracker) – \(appearanceName.rawValue)")
                } else {
                    XCTAssertNotNil(feedLogo, "\(tracker) – \(appearanceName.rawValue)")
                }

                logos[appearanceName, default: [:]][tracker] = logo

                // shouldn‘t be regenerated
                XCTAssertEqual(PrivacyIconViewModel.logo(for: tracker.rawValue), logo,
                               "\(tracker) – \(appearanceName.rawValue)")
                XCTAssertEqual(HomePage.Models.RecentlyVisitedSiteModel.feedImage(for: tracker)?.cgImage(forProposedRect: nil, context: .current, hints: nil),
                               feedLogo,
                               "\(tracker) – \(appearanceName.rawValue)")

                // dark image should be different from aqua
                if case .darkAqua = appearanceName {
                    XCTAssertNotEqual(logos[.aqua]![tracker], logo)
                }
            }

            for ascii in UInt8(ascii: "a")...UInt8(ascii: "z") {
                let letter = Character(UnicodeScalar(ascii))
                let letterImage = PrivacyIconViewModel.letters[letter]

                XCTAssertNotNil(letterImage,
                                "\(letter) – \(appearanceName.rawValue)")
                XCTAssertEqual(letterImage, PrivacyIconViewModel.letters[letter],
                               "\(letter) – \(appearanceName.rawValue)") // shouldn‘t be regenerated

                letterImages[appearanceName, default: [:]][letter] = letterImage

                // dark image should be different from aqua
                if case .darkAqua = appearanceName {
                    XCTAssertNotEqual(letterImages[.aqua]![letter], letterImage)
                }
            }

            let blankTrackerImage = PrivacyIconViewModel.blankTrackerImage
            let shadowTrackerImage = PrivacyIconViewModel.shadowTrackerImage
            XCTAssertNotNil(blankTrackerImage)
            XCTAssertNotNil(shadowTrackerImage)
            XCTAssertEqual(PrivacyIconViewModel.blankTrackerImage, blankTrackerImage) // shouldn‘t be regenerated
            XCTAssertEqual(PrivacyIconViewModel.shadowTrackerImage, shadowTrackerImage) // shouldn‘t be regenerated

            blankTrackerImages[appearanceName] = blankTrackerImage
            shadowTrackerImages[appearanceName] = shadowTrackerImage
        }

        // dark image should be different from aqua
        XCTAssertNotEqual(blankTrackerImages[.aqua], blankTrackerImages[.darkAqua])
        XCTAssertNotEqual(shadowTrackerImages[.aqua], shadowTrackerImages[.darkAqua])
    }

}
