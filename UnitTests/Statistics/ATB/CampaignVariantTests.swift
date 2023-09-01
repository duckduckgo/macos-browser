//
//  CampaignVariantTests.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

class CampaignVariantTests: XCTestCase, StatisticsStore {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.set(nil, forKey: UserDefaultsWrapper<Any>.Key.campaignVariant.rawValue)
    }

    func testWhenNoVariantFileThenNoVariantAssigned() {
        let campaign = CampaignVariant(statisticsStore: self, loadFromFile: {
            return nil
        })
        XCTAssertNil(campaign.getAndEnableVariant())
    }

    func testWhenVariantPresentAndDateIn0To93DaysThenIsActive() {
        let campaign = CampaignVariant(statisticsStore: self, loadFromFile: {
            return "ab"
        })
        XCTAssertEqual(campaign.getAndEnableVariant(), "ab")

        installDate = .startOfDayToday
        XCTAssertTrue(campaign.isActive)

        installDate = .startOfDayToday.addingTimeInterval(-60 * 60 * 24 * 93)
        XCTAssertTrue(campaign.isActive)

        installDate = .startOfDayToday.addingTimeInterval(-60 * 60 * 24 * 94)
        XCTAssertFalse(campaign.isActive)
    }

    func testWhenCampaignVariantAvailableThenVariantManagerUsesCampaignVariant() {
        let campaign = CampaignVariant(statisticsStore: self, loadFromFile: {
            return "ab"
        })
        let mgr = DefaultVariantManager(storage: self, campaignVariant: campaign)
        mgr.assignVariantIfNeeded { _ in
            // no-op
        }
        XCTAssertEqual(variant, "ab")
    }

    // MARK: Mock items

    var installDate: Date?
    var atb: String?
    var searchRetentionAtb: String?
    var appRetentionAtb: String?
    var variant: String?
    var lastAppRetentionRequestDate: Date?
    var waitlistUnlocked: Bool = false
    var autoLockEnabled: Bool = false
    var autoLockThreshold: String?

}
