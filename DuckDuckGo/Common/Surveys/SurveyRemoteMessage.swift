//
//  SurveyRemoteMessage.swift
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
import Common
import Subscription

struct SurveyRemoteMessageAction: Codable, Equatable, Hashable {
    enum Action: String, Codable {
        case openSurveyURL
        case openURL
    }

    let actionTitle: String
    let actionType: Action?
    let actionURL: String?
}

struct SurveyRemoteMessage: Codable, Equatable, Identifiable, Hashable {

    struct Attributes: Codable, Equatable, Hashable {
        let subscriptionStatus: String?
        let subscriptionBillingPeriod: String?
        let sparkleSubscriptionPurchasePlatforms: [String]?
        let appStoreSubscriptionPurchasePlatforms: [String]?
        let minimumDaysSinceSubscriptionStarted: Int?
        let maximumDaysUntilSubscriptionExpirationOrRenewal: Int?
        let daysSinceVPNEnabled: Int?
        let daysSincePIREnabled: Int?
    }

    let id: String
    let cardTitle: String
    let cardDescription: String
    let attributes: Attributes
    let action: SurveyRemoteMessageAction

    func presentableSurveyURL(
        statisticsStore: StatisticsStore = LocalStatisticsStore(),
        vpnActivationDateStore: WaitlistActivationDateStore = DefaultWaitlistActivationDateStore(source: .netP),
        pirActivationDateStore: WaitlistActivationDateStore = DefaultWaitlistActivationDateStore(source: .dbp),
        operatingSystemVersion: String = ProcessInfo.processInfo.operatingSystemVersion.description,
        appVersion: String = AppVersion.shared.versionNumber,
        hardwareModel: String? = HardwareModel.model,
        subscription: Subscription?
    ) -> URL? {
        if let actionType = action.actionType, actionType == .openURL, let urlString = action.actionURL, let url = URL(string: urlString) {
            return url
        }

        guard let actionType = action.actionType, actionType == .openSurveyURL, let surveyURL = action.actionURL else {
            return nil
        }

        let surveyURLBuilder = SurveyURLBuilder(
            statisticsStore: statisticsStore,
            operatingSystemVersion: operatingSystemVersion,
            appVersion: appVersion,
            hardwareModel: hardwareModel,
            subscription: subscription,
            daysSinceVPNActivated: vpnActivationDateStore.daysSinceActivation(),
            daysSinceVPNLastActive: vpnActivationDateStore.daysSinceLastActive(),
            daysSincePIRActivated: pirActivationDateStore.daysSinceActivation(),
            daysSincePIRLastActive: pirActivationDateStore.daysSinceLastActive()
        )

        return surveyURLBuilder.buildSurveyURL(from: surveyURL)
    }
}
