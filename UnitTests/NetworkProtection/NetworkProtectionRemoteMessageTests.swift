//
//  NetworkProtectionRemoteMessageTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

final class NetworkProtectionRemoteMessageTests: XCTestCase {

    func testWhenDecodingMessages_ThenMessagesDecodeSuccessfully() throws {
        let mockStatisticsStore = MockStatisticsStore()
        mockStatisticsStore.atb = "atb-123"
        mockStatisticsStore.variant = "variant"

        let mockActivationDateStore = MockWaitlistActivationDateStore()
        mockActivationDateStore._daysSinceActivation = 0
        mockActivationDateStore._daysSinceLastActive = 0

        let fileURL = mockMessagesURL()
        let data = try Data(contentsOf: fileURL)

        let decoder = JSONDecoder()
        let decodedMessages = try decoder.decode([NetworkProtectionRemoteMessage].self, from: data)

        XCTAssertEqual(decodedMessages.count, 3)

        guard let firstMessage = decodedMessages.first(where: { $0.id == "123"}) else {
            XCTFail("Failed to find expected message")
            return
        }

        let firstMessagePresentableSurveyURL = firstMessage.presentableSurveyURL(
            statisticsStore: mockStatisticsStore,
            activationDateStore: mockActivationDateStore,
            operatingSystemVersion: "1.2.3",
            appVersion: "4.5.6",
            hardwareModel: "MacBookPro,123"
        )

        XCTAssertEqual(firstMessage.cardTitle, "Title 1")
        XCTAssertEqual(firstMessage.cardDescription, "Description 1")
        XCTAssertEqual(firstMessage.action.actionTitle, "Action 1")
        XCTAssertNil(firstMessagePresentableSurveyURL)
        XCTAssertNil(firstMessage.daysSinceNetworkProtectionEnabled)

        guard let secondMessage = decodedMessages.first(where: { $0.id == "456"}) else {
            XCTFail("Failed to find expected message")
            return
        }

        let secondMessagePresentableSurveyURL = secondMessage.presentableSurveyURL(
            statisticsStore: mockStatisticsStore,
            activationDateStore: mockActivationDateStore,
            operatingSystemVersion: "1.2.3",
            appVersion: "4.5.6",
            hardwareModel: "MacBookPro,123"
        )

        XCTAssertEqual(secondMessage.daysSinceNetworkProtectionEnabled, 1)
        XCTAssertEqual(secondMessage.cardTitle, "Title 2")
        XCTAssertEqual(secondMessage.cardDescription, "Description 2")
        XCTAssertEqual(secondMessage.action.actionTitle, "Action 2")
        XCTAssertNil(secondMessagePresentableSurveyURL)

        guard let thirdMessage = decodedMessages.first(where: { $0.id == "789"}) else {
            XCTFail("Failed to find expected message")
            return
        }

        let thirdMessagePresentableSurveyURL = thirdMessage.presentableSurveyURL(
            statisticsStore: mockStatisticsStore,
            activationDateStore: mockActivationDateStore,
            operatingSystemVersion: "1.2.3",
            appVersion: "4.5.6",
            hardwareModel: "MacBookPro,123"
        )

        XCTAssertEqual(thirdMessage.daysSinceNetworkProtectionEnabled, 5)
        XCTAssertEqual(thirdMessage.cardTitle, "Title 3")
        XCTAssertEqual(thirdMessage.cardDescription, "Description 3")
        XCTAssertEqual(thirdMessage.action.actionTitle, "Action 3")
        XCTAssertTrue(thirdMessagePresentableSurveyURL!.absoluteString.hasPrefix("https://duckduckgo.com/"))
    }

    func testWhenGettingSurveyURL_AndSurveyURLHasParameters_ThenParametersAreReplaced() {
        let remoteMessageJSON = """
        {
            "id": "1",
            "daysSinceNetworkProtectionEnabled": 0,
            "cardTitle": "Title",
            "cardDescription": "Description",
            "requiresNetworkProtectionAccess": true,
            "requiresNetworkProtectionUsage": true,
            "action": {
                "actionTitle": "Action",
                "actionURL": "https://duckduckgo.com/"
            }
        }
        """

        let decoder = JSONDecoder()
        let message: NetworkProtectionRemoteMessage
        do {
            message = try decoder.decode(NetworkProtectionRemoteMessage.self, from: remoteMessageJSON.data(using: .utf8)!)
        } catch {
            XCTFail("Failed to decode with error: \(error.localizedDescription)")
            return
        }

        let mockStatisticsStore = MockStatisticsStore()
        mockStatisticsStore.atb = "atb-123"
        mockStatisticsStore.variant = "variant"

        let mockActivationDateStore = MockWaitlistActivationDateStore()
        mockActivationDateStore._daysSinceActivation = 2
        mockActivationDateStore._daysSinceLastActive = 1

        let presentableSurveyURL = message.presentableSurveyURL(
            statisticsStore: mockStatisticsStore,
            activationDateStore: mockActivationDateStore,
            operatingSystemVersion: "1.2.3",
            appVersion: "4.5.6",
            hardwareModel: "MacBookPro,123"
        )

        let expectedURL = "https://duckduckgo.com/?atb=atb-123&var=variant&delta=2&mv=1.2.3&ddgv=4.5.6&mo=MacBookPro%252C123&da=1"
        XCTAssertEqual(presentableSurveyURL!.absoluteString, expectedURL)
    }

    private func mockMessagesURL() -> URL {
        let bundle = Bundle(for: NetworkProtectionRemoteMessageTests.self)
        return bundle.resourceURL!.appendingPathComponent("network-protection-messages.json")
    }

}
