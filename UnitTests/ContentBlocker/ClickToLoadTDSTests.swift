//
//  ClickToLoadTDSTests.swift
//
//  Copyright © 2019 DuckDuckGo. All rights reserved.
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

private extension KnownTracker {

    var countCTLActions: Int {
        var count = 0

        if let rules = rules {
            for rule in rules {
                if let action = rule.action, action == .blockCTLFB {
                    count += 1
                }
            }
        }
        return count
    }

}

class ClickToLoadTDSTests: XCTestCase {

    func testEnsureClickToLoadTDSCompiles() throws {

        let trackerData = AppTrackerDataSetProvider().embeddedData
        let etag = AppTrackerDataSetProvider().embeddedDataEtag
        let trackerManager = TrackerDataManager(etag: etag,
                                         data: trackerData,
                                         embeddedDataProvider: AppTrackerDataSetProvider())
        let mockAdAttributing = MockAttributing()

        let cbrLists = ContentBlockerRulesLists(trackerDataManager: trackerManager, adClickAttribution: mockAdAttributing)
        let ruleSets = cbrLists.contentBlockerRulesLists
        let tdsName = ContentBlockerRulesLists.Constants.clickToLoadRulesListName

        let ctlRules = ruleSets.first(where: { $0.name == tdsName})
        let ctlTrackerData = ctlRules?.trackerData
        let ctlTds = ctlTrackerData?.tds

        let builder = ContentBlockerRulesBuilder(trackerData: ctlTds!)

        let rules = builder.buildRules(withExceptions: [],
                                       andTemporaryUnprotectedDomains: [],
                                       andTrackerAllowlist: [])

        let data = try JSONEncoder().encode(rules)
        let ruleList = String(data: data, encoding: .utf8)!

        let identifier = UUID().uuidString

        let compiled = expectation(description: "Rules compiled")

        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: identifier,
                                                                encodedContentRuleList: ruleList) { result, error in
            XCTAssertNotNil(result)
            XCTAssertNil(error)
            compiled.fulfill()
        }

        wait(for: [compiled], timeout: 30.0)

        let removed = expectation(description: "Rules removed")

        WKContentRuleListStore.default().removeContentRuleList(forIdentifier: identifier) { _ in
            removed.fulfill()
        }

        wait(for: [removed], timeout: 5.0)
    }

    func testClickToLoadTDSSplit() throws {

        let trackerData = AppTrackerDataSetProvider().embeddedData
        let etag = AppTrackerDataSetProvider().embeddedDataEtag
        let trackerManager = TrackerDataManager(etag: etag,
                                         data: trackerData,
                                         embeddedDataProvider: AppTrackerDataSetProvider())
        let mockAdAttributing = MockAttributing()

        let cbrLists = ContentBlockerRulesLists(trackerDataManager: trackerManager, adClickAttribution: mockAdAttributing)
        let ruleSets = cbrLists.contentBlockerRulesLists
        let ctlTdsName = ContentBlockerRulesLists.Constants.clickToLoadRulesListName
        let mainTdsName = DefaultContentBlockerRulesListsSource.Constants.trackerDataSetRulesListName

        let mainRules = ruleSets.first(where: { $0.name == mainTdsName})
        let ctlRules = ruleSets.first(where: { $0.name == ctlTdsName})

        let mainTrackerData = mainRules?.trackerData
        let mainTrackers = mainTrackerData?.tds.trackers

        let ctlTrackerData = ctlRules?.trackerData
        let ctlTrackers = ctlTrackerData?.tds.trackers

        let fbMainTracker = mainTrackers?["facebook.net"]
        let fbCtlTracker = ctlTrackers?["facebook.net"]

        let fbMainRules = fbMainTracker?.rules
        let fbCtlRules = fbCtlTracker?.rules

        let fbMainRuleCount = fbMainRules!.count
        let fbCtlRuleCount = fbCtlRules!.count

        let mainCtlRuleCount = fbMainTracker!.countCTLActions
        let ctlCtlRuleCount = fbCtlTracker!.countCTLActions

        // ensure both rulesets contains facebook.net rules
        XCTAssert(fbMainRuleCount > 0)
        XCTAssert(fbCtlRuleCount > 0)

        // ensure FB CTL rules include CTL custom actions, and main rules FB do not
        XCTAssert(mainCtlRuleCount == 0)
        XCTAssert(ctlCtlRuleCount > 0)

        // ensure FB CTL rules are the sum of the main rules + CTL custom action rules
        XCTAssert(fbMainRuleCount + ctlCtlRuleCount == fbCtlRuleCount)

    }
}
