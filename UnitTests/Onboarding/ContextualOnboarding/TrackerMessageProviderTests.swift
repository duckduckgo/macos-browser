//
//  TrackerMessageProviderTests.swift
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

import XCTest
import TrackerRadarKit
import PrivacyDashboard
import ContentBlocking
@testable import DuckDuckGo_Privacy_Browser

final class TrackerMessageProviderTests: XCTestCase {

    var mockEntityProvider: MockEntityProviding!
    var trackerMessageProvider: TrackerMessageProvider!
    let googleEntity = Entity(displayName: "Google", domains: ["google.com"], prevalence: 0.9)
    let facebookEntity = Entity(displayName: "Facebook", domains: ["facebook.com"], prevalence: 0.8)
    let trackerEntity1 = Entity(displayName: "Tracker1", domains: ["tracker1.com"], prevalence: 0.8)
    let trackerEntity2 = Entity(displayName: "Tracker2", domains: ["tracker2.com"], prevalence: 0.8)
    let trackerEntity3 = Entity(displayName: "Tracker3", domains: ["tracker3.com"], prevalence: 0.8)

    override func setUp() {
        super.setUp()
        mockEntityProvider = MockEntityProviding(entities: [
            "google.com": googleEntity,
            "facebook.com": facebookEntity,
            "fbcdn.net": facebookEntity,
            "ggl.net": googleEntity
        ])
        trackerMessageProvider = TrackerMessageProvider(entityProviding: mockEntityProvider)
    }

    func testTrackersType_WhenDomainIsGoogle_ReturnsMajorTracker() {
        let expectedMessage: String = "Heads up! I can’t stop Google from seeing your activity on google.com.\n\nBut browse with me, and I can reduce what Google knows about you overall by blocking their trackers on lots of other sites."
        let protectionStatus = ProtectionStatus(unprotectedTemporary: false, enabledFeatures: [], allowlisted: false, denylisted: false)
        let privacyInfo = PrivacyInfo(url: URL(string: "https://google.com")!,
                                      parentEntity: googleEntity,
                                      protectionStatus: protectionStatus)

        let trackerType = trackerMessageProvider.trackersType(privacyInfo: privacyInfo)
        let message = trackerMessageProvider.trackerMessage(privacyInfo: privacyInfo)

        XCTAssertEqual(trackerType, .majorTracker)
        XCTAssertEqual(message?.string, expectedMessage)
    }

    func testTrackersType_WhenDomainIsFacebook_ReturnsMajorTracker() {
        let expectedMessage: String = "Heads up! I can’t stop Facebook from seeing your activity on facebook.com.\n\nBut browse with me, and I can reduce what Facebook knows about you overall by blocking their trackers on lots of other sites."
        let protectionStatus = ProtectionStatus(unprotectedTemporary: false, enabledFeatures: [], allowlisted: false, denylisted: false)
        let privacyInfo = PrivacyInfo(url: URL(string: "https://facebook.com")!,
                                      parentEntity: facebookEntity,
                                      protectionStatus: protectionStatus)

        let trackerType = trackerMessageProvider.trackersType(privacyInfo: privacyInfo)
        let message = trackerMessageProvider.trackerMessage(privacyInfo: privacyInfo)

        XCTAssertEqual(trackerType, .majorTracker)
        XCTAssertEqual(message?.string, expectedMessage)
    }

    func testTrackersType_WhenDomainIsOwnedByFacebook_ReturnsOwnedByMajorTracker() {
        let expectedMessage: String = "Heads up! Since Facebook owns fbcdn.net, I can’t stop them from seeing your activity here.\n\nBut browse with me, and I can reduce what Facebook knows about you overall by blocking their trackers on lots of other sites."
        let protectionStatus = ProtectionStatus(unprotectedTemporary: false, enabledFeatures: [], allowlisted: false, denylisted: false)
        let privacyInfo = PrivacyInfo(url: URL(string: "https://fbcdn.net")!,
                                      parentEntity: facebookEntity,
                                      protectionStatus: protectionStatus)

        let trackerType = trackerMessageProvider.trackersType(privacyInfo: privacyInfo)
        let message = trackerMessageProvider.trackerMessage(privacyInfo: privacyInfo)

        XCTAssertEqual(trackerType, .ownedByMajorTracker(owner: facebookEntity))
        XCTAssertEqual(message?.string, expectedMessage)
    }

    func testTrackersType_WhenDomainIsOwnedByGoogle_ReturnsOwnedByMajorTracker() {
        let expectedMessage: String = "Heads up! Since Google owns ggl.net, I can’t stop them from seeing your activity here.\n\nBut browse with me, and I can reduce what Google knows about you overall by blocking their trackers on lots of other sites."
        let protectionStatus = ProtectionStatus(unprotectedTemporary: false, enabledFeatures: [], allowlisted: false, denylisted: false)
        let privacyInfo = PrivacyInfo(url: URL(string: "https://ggl.net")!,
                                      parentEntity: facebookEntity,
                                      protectionStatus: protectionStatus)

        let trackerType = trackerMessageProvider.trackersType(privacyInfo: privacyInfo)
        let message = trackerMessageProvider.trackerMessage(privacyInfo: privacyInfo)

        XCTAssertEqual(trackerType, .ownedByMajorTracker(owner: googleEntity))
        XCTAssertEqual(message?.string, expectedMessage)
    }

    func testTrackersType_WhenNoTrackers_ReturnsNoTrackers() {
        let expectedMessage: String = "As you tap and scroll, I’ll block pesky trackers.\n\nGo ahead - keep browsing!"
        let protectionStatus = ProtectionStatus(unprotectedTemporary: false, enabledFeatures: [], allowlisted: false, denylisted: false)
        let privacyInfo = PrivacyInfo(url: URL(string: "https://unknown.com")!,
                                      parentEntity: nil,
                                      protectionStatus: protectionStatus)
        let trackerType = trackerMessageProvider.trackersType(privacyInfo: privacyInfo)
        let message = trackerMessageProvider.trackerMessage(privacyInfo: privacyInfo)

        XCTAssertEqual(trackerType, .noTrackers)
        XCTAssertEqual(message?.string, expectedMessage)
    }

    func testTrackerType_When1Tracker_ReturnsExpectedMessage() {
        let expectedMessage: String = "Tracker1 was trying to track you here. I blocked them!\n\n☝️ Tap the shield for more info."
        let protectionStatus = ProtectionStatus(unprotectedTemporary: false, enabledFeatures: [], allowlisted: false, denylisted: false)
        let privacyInfo = PrivacyInfo(url: URL(string: "https://site-with-tracker.com")!,
                                      parentEntity: nil,
                                      protectionStatus: protectionStatus)
        let detectedTracker = DetectedRequest(url: "https://site-with-tracker.com", eTLDplus1: "https://site-with-tracker.com", knownTracker: nil, entity: trackerEntity1, state: .blocked, pageUrl: "https://site-with-tracker.com")
        privacyInfo.trackerInfo.addDetectedTracker(detectedTracker, onPageWithURL: URL(string: "https://site-with-tracker.com")!)

        let trackerType = trackerMessageProvider.trackersType(privacyInfo: privacyInfo)
        let message = trackerMessageProvider.trackerMessage(privacyInfo: privacyInfo)

        XCTAssertEqual(trackerType, .blockedTrackers(entityNames: ["Tracker1"]))
        XCTAssertEqual(message?.string, expectedMessage)
    }

    func testTrackerType_When2Trackers_ReturnsExpectedMessage() throws {
        let expectedMessage: String = "were trying to track you here. I blocked them!"
        let protectionStatus = ProtectionStatus(unprotectedTemporary: false, enabledFeatures: [], allowlisted: false, denylisted: false)
        let privacyInfo = PrivacyInfo(url: URL(string: "https://site-with-tracker.com")!,
                                      parentEntity: nil,
                                      protectionStatus: protectionStatus)
        let detectedTracker = DetectedRequest(url: "https://site-with-tracker.com", eTLDplus1: "https://site-with-tracker.com", knownTracker: nil, entity: trackerEntity1, state: .blocked, pageUrl: "https://site-with-tracker.com")
        let detectedTracker2 = DetectedRequest(url: "https://site-with-tracker2.com", eTLDplus1: "https://site-with-tracker2.com", knownTracker: nil, entity: trackerEntity2, state: .blocked, pageUrl: "https://site-with-tracker2.com")
        privacyInfo.trackerInfo.addDetectedTracker(detectedTracker, onPageWithURL: URL(string: "https://site-with-tracker.com")!)
        privacyInfo.trackerInfo.addDetectedTracker(detectedTracker2, onPageWithURL: URL(string: "https://site-with-tracker2.com")!)

        let trackerType = trackerMessageProvider.trackersType(privacyInfo: privacyInfo)
        let message = try XCTUnwrap(trackerMessageProvider.trackerMessage(privacyInfo: privacyInfo))
        let expectedEntityNames = Set(["Tracker1", "Tracker2"])

        if case .blockedTrackers(let entityNames) = trackerType {
            XCTAssertEqual(Set(entityNames), expectedEntityNames)
        } else {
            XCTFail("Expected .blockedTrackers, but got \(String(describing: trackerType))")
        }
        XCTAssertTrue(message.string.contains(expectedMessage))
    }

    func testTrackerType_When3Trackers_ReturnsExpectedMessage() throws {
        let expectedMessage: String = "were trying to track you here. I blocked them!"
        let protectionStatus = ProtectionStatus(unprotectedTemporary: false, enabledFeatures: [], allowlisted: false, denylisted: false)
        let privacyInfo = PrivacyInfo(url: URL(string: "https://site-with-tracker.com")!,
                                      parentEntity: nil,
                                      protectionStatus: protectionStatus)
        let detectedTracker = DetectedRequest(url: "https://site-with-tracker.com", eTLDplus1: "https://site-with-tracker.com", knownTracker: nil, entity: trackerEntity1, state: .blocked, pageUrl: "https://site-with-tracker.com")
        let detectedTracker2 = DetectedRequest(url: "https://site-with-tracker2.com", eTLDplus1: "https://site-with-tracker2.com", knownTracker: nil, entity: trackerEntity2, state: .blocked, pageUrl: "https://site-with-tracker2.com")
        let detectedTracker3 = DetectedRequest(url: "https://site-with-tracker3.com", eTLDplus1: "https://site-with-tracker3.com", knownTracker: nil, entity: trackerEntity3, state: .blocked, pageUrl: "https://site-with-tracker3.com")
        privacyInfo.trackerInfo.addDetectedTracker(detectedTracker, onPageWithURL: URL(string: "https://site-with-tracker.com")!)
        privacyInfo.trackerInfo.addDetectedTracker(detectedTracker2, onPageWithURL: URL(string: "https://site-with-tracker2.com")!)
        privacyInfo.trackerInfo.addDetectedTracker(detectedTracker3, onPageWithURL: URL(string: "https://site-with-tracker3.com")!)

        let trackerType = trackerMessageProvider.trackersType(privacyInfo: privacyInfo)
        let message = try XCTUnwrap(trackerMessageProvider.trackerMessage(privacyInfo: privacyInfo))
        let expectedEntityNames = Set(["Tracker1", "Tracker2", "Tracker3"])

        if case .blockedTrackers(let entityNames) = trackerType {
            XCTAssertEqual(Set(entityNames), expectedEntityNames)
        } else {
            XCTFail("Expected .blockedTrackers, but got \(String(describing: trackerType))")
        }
        XCTAssertTrue(message.string.contains(expectedMessage))
    }

}

class MockEntityProviding: EntityProviding {
    private var entities: [String: Entity]

    init(entities: [String: Entity]) {
        self.entities = entities
    }

    func entity(forHost host: String) -> Entity? {
        return entities[host]
    }
}

class MockSecurityTrust: SecurityTrust {}
