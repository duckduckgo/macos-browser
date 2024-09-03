//
//  ContentBlockingUpdatingTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import WebKit
import Common
import TrackerRadarKit
import BrowserServicesKit
@testable import DuckDuckGo_Privacy_Browser

final class ContentBlockingUpdatingTests: XCTestCase {

    let preferences = WebTrackingProtectionPreferences.shared
    let rulesManager = ContentBlockerRulesManagerMock()
    var updating: UserContentUpdating!

    @MainActor
    override func setUp() {
        let configStore = ConfigurationStore()
        updating = UserContentUpdating(contentBlockerRulesManager: rulesManager,
                                       privacyConfigurationManager: MockPrivacyConfigurationManager(),
                                       trackerDataManager: TrackerDataManager(etag: configStore.loadEtag(for: .trackerDataSet),
                                                                              data: configStore.loadData(for: .trackerDataSet),
                                                                              embeddedDataProvider: AppTrackerDataSetProvider(),
                                                                              errorReporting: nil),
                                       configStorage: MockConfigurationStore(),
                                       webTrackingProtectionPreferences: preferences,
                                       tld: TLD())
    }

    override static func setUp() {
        // WKContentRuleList uses native c++ _contentRuleList api object and calls ~ContentRuleList on dealloc
        // let it just leak
        WKContentRuleList.swizzleDealloc()
    }
    override static func tearDown() {
        WKContentRuleList.restoreDealloc()
    }

    func testInitialUpdateIsBuffered() {
        rulesManager.updatesSubject.send(Self.testUpdate())

        let e = expectation(description: "should publish rules")
        let c = updating.userContentBlockingAssets.sink { assets in
            XCTAssertTrue(assets.isValid)
            e.fulfill()
        }

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 0, handler: nil)
        }
    }

    func testWhenRuleListIsRecompiledThenUpdatesAreReceived() {
        rulesManager.updatesSubject.send(Self.testUpdate())

        let e = expectation(description: "should publish rules 3 times")
        var ruleList1: WKContentRuleList?
        var ruleList2: WKContentRuleList?
        let c = updating.userContentBlockingAssets.sink { assets in
            switch (ruleList1, ruleList2) {
            case (.none, _):
                ruleList1 = assets.rules(withName: "test")
            case (.some, .none):
                ruleList2 = assets.rules(withName: "test")
            case (.some(let list1), .some(let list2)):
                XCTAssertFalse(list1 == list2)
                XCTAssertFalse(assets.rules(withName: "test") === list2)
                e.fulfill()
            }
        }

        rulesManager.updatesSubject.send(Self.testUpdate())
        rulesManager.updatesSubject.send(Self.testUpdate())

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 0, handler: nil)
        }
    }

    func testWhenGPCEnabledChangesThenUserScriptsAreRebuild() {
        let e = expectation(description: "should rebuild user scripts")
        var ruleList: WKContentRuleList!
        let c = updating.userContentBlockingAssets.sink { assets in
            if ruleList == nil {
                ruleList = assets.rules(withName: "test")
            } else {
                // ruleList should not be recompiled
                XCTAssertTrue(assets.rules(withName: "test") === ruleList)
                XCTAssertTrue(assets.isValid)

                e.fulfill()
            }
        }

        rulesManager.updatesSubject.send(Self.testUpdate())
        preferences.isGPCEnabled = !preferences.isGPCEnabled

        withExtendedLifetime(c) {
            waitForExpectations(timeout: 0, handler: nil)
        }
    }

    func testWhenRuleListIsRecompiledThenCompletionTokensArePublished() {
        let update1 = Self.testUpdate()
        let update2 = Self.testUpdate()
        var update1received = false
        let e = expectation(description: "2 updates received")
        let c = updating.userContentBlockingAssets.map { $0.rulesUpdate.completionTokens }.sink { tokens in
            if !update1received {
                XCTAssertEqual(tokens, update1.completionTokens)
                update1received = true
            } else {
                XCTAssertEqual(tokens, update2.completionTokens)
                e.fulfill()
            }
        }

        rulesManager.updatesSubject.send(update1)
        rulesManager.updatesSubject.send(update2)

        c.cancel()
        withExtendedLifetime(c) {
            waitForExpectations(timeout: 0, handler: nil)
        }
    }

    // MARK: - Test data

    static let tracker = KnownTracker(domain: "tracker.com",
                               defaultAction: .block,
                               owner: KnownTracker.Owner(name: "Tracker Inc",
                                                         displayName: "Tracker Inc company",
                                                         ownedBy: "Owner"),
                               prevalence: 0.1,
                               subdomains: nil,
                               categories: nil,
                               rules: nil)

    static let tds = TrackerData(trackers: ["tracker.com": tracker],
                                 entities: ["Tracker Inc": Entity(displayName: "Trackr Inc company",
                                                                  domains: ["tracker.com"],
                                                                  prevalence: 0.1)],
                                 domains: ["tracker.com": "Tracker Inc"],
                                 cnames: [:])
    static let encodedTrackerData = String(data: (try? JSONEncoder().encode(tds))!, encoding: .utf8)!

    static func testRules() -> [ContentBlockerRulesManager.Rules] {
        [.init(name: "test",
               rulesList: WKContentRuleList(),
               trackerData: tds,
               encodedTrackerData: encodedTrackerData,
               etag: "asd",
               identifier: ContentBlockerRulesIdentifier(name: "test",
                                                         tdsEtag: "asd",
                                                         tempListId: nil,
                                                         allowListId: nil,
                                                         unprotectedSitesHash: nil))]
    }

    static func testUpdate() -> ContentBlockerRulesManager.UpdateEvent {
        .init(rules: testRules(), changes: [:], completionTokens: [UUID().uuidString, UUID().uuidString])
    }

}

extension UserContentControllerNewContent {

    func rules(withName name: String) -> WKContentRuleList? {
        rulesUpdate.rules.first(where: { $0.name == name})?.rulesList
    }

    var isValid: Bool {
        return rules(withName: "test") != nil
    }
}

extension WKContentRuleList {

    private static var isSwizzled = false
    private static let originalDealloc = {
        class_getInstanceMethod(WKContentRuleList.self, NSSelectorFromString("dealloc"))!
    }()
    private static let swizzledDealloc = {
        class_getInstanceMethod(WKContentRuleList.self, #selector(swizzled_dealloc))!
    }()

    static func swizzleDealloc() {
        guard !self.isSwizzled else { return }
        self.isSwizzled = true
        method_exchangeImplementations(originalDealloc, swizzledDealloc)
    }

    static func restoreDealloc() {
        guard self.isSwizzled else { return }
        self.isSwizzled = false
        method_exchangeImplementations(originalDealloc, swizzledDealloc)
    }

    @objc
    func swizzled_dealloc() {
    }

}
