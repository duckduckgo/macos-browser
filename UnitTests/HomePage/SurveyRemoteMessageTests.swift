//
//  SurveyRemoteMessageTests.swift
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

final class SurveyRemoteMessageTests: XCTestCase {

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
        let decodedMessages = try decoder.decode([SurveyRemoteMessage].self, from: data)

        XCTAssertEqual(decodedMessages.count, 1)

        guard let firstMessage = decodedMessages.first(where: { $0.id == "message-1"}) else {
            XCTFail("Failed to find expected message")
            return
        }

        let firstMessagePresentableSurveyURL = firstMessage.presentableSurveyURL(
            statisticsStore: mockStatisticsStore,
            vpnActivationDateStore: mockActivationDateStore,
            operatingSystemVersion: "1.2.3",
            appVersion: "4.5.6",
            hardwareModel: "MacBookPro,123",
            subscription: nil
        )

        XCTAssertEqual(firstMessage.cardTitle, "Title 1")
        XCTAssertEqual(firstMessage.cardDescription, "Description 1")
        XCTAssertEqual(firstMessage.action.actionTitle, "Action 1")
        XCTAssertEqual(firstMessage.attributes.minimumDaysSinceSubscriptionStarted, 1)
        XCTAssertEqual(firstMessage.attributes.daysSinceVPNEnabled, 2)
        XCTAssertEqual(firstMessage.attributes.daysSincePIREnabled, 3)
        XCTAssertEqual(firstMessage.attributes.maximumDaysUntilSubscriptionExpirationOrRenewal, 30)
        XCTAssertEqual(firstMessage.attributes.appStoreSubscriptionPurchasePlatforms, ["stripe"])
        XCTAssertEqual(firstMessage.attributes.sparkleSubscriptionPurchasePlatforms, ["stripe"])
        XCTAssertNotNil(firstMessagePresentableSurveyURL)
    }

    func testWhenGettingSurveyURL_AndSurveyURLHasParameters_ThenParametersAreReplaced() {
        let remoteMessageJSON = """
        {
            "id": "1",
            "daysSinceNetworkProtectionEnabled": 0,
            "cardTitle": "Title",
            "cardDescription": "Description",
            "attributes": {
                "subscriptionStatus": "",
                "minimumDaysSinceSubscriptionStarted": 1,
                "maximumDaysUntilSubscriptionExpirationOrRenewal": 30,
                "daysSinceVPNEnabled": 1,
                "daysSincePIREnabled": 1
            },
            "action": {
                "actionTitle": "Action",
                "actionType": "openSurveyURL",
                "actionURL": "https://duckduckgo.com/"
            }
        }
        """

        let decoder = JSONDecoder()
        let message: SurveyRemoteMessage
        do {
            message = try decoder.decode(SurveyRemoteMessage.self, from: remoteMessageJSON.data(using: .utf8)!)
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
            vpnActivationDateStore: mockActivationDateStore,
            operatingSystemVersion: "1.2.3",
            appVersion: "4.5.6",
            hardwareModel: "MacBookPro,123",
            subscription: nil
        )

        let expectedURL = """
        https://duckduckgo.com/?atb=atb-123&var=variant&osv=1.2.3&ddgv=4.5.6&mo=MacBookPro%252C123&vpn_first_used=2&vpn_last_used=1
        """

        XCTAssertEqual(presentableSurveyURL!.absoluteString, expectedURL)
    }

    private func mockMessagesURL() -> URL {
        let bundle = Bundle(for: SurveyRemoteMessageTests.self)
        return bundle.resourceURL!.appendingPathComponent("survey-messages.json")
    }

}
