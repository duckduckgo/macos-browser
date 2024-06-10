//
//  SurveyURLBuilder.swift
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

final class SurveyURLBuilder {

    enum SurveyURLParameters: String, CaseIterable {
        case atb = "atb"
        case atbVariant = "var"
        case macOSVersion = "osv"
        case appVersion = "ddgv"
        case hardwareModel = "mo"

        case privacyProStatus = "ppro_status"
        case privacyProPurchasePlatform = "ppro_platform"
        case privacyProBillingPeriod = "ppro_billing"
        case privacyProDaysSincePurchase = "ppro_days_since_purchase"
        case privacyProDaysUntilExpiration = "ppro_days_until_exp"

        case vpnFirstUsed = "vpn_first_used"
        case vpnLastUsed = "vpn_last_used"
        case pirFirstUsed = "pir_first_used"
        case pirLastUsed = "pir_last_used"
    }

    private let statisticsStore: StatisticsStore
    private let operatingSystemVersion: String
    private let appVersion: String
    private let hardwareModel: String?
    private let subscription: Subscription?
    private let daysSinceVPNActivated: Int?
    private let daysSinceVPNLastActive: Int?
    private let daysSincePIRActivated: Int?
    private let daysSincePIRLastActive: Int?

    init(statisticsStore: StatisticsStore,
         operatingSystemVersion: String,
         appVersion: String,
         hardwareModel: String?,
         subscription: Subscription?,
         daysSinceVPNActivated: Int?,
         daysSinceVPNLastActive: Int?,
         daysSincePIRActivated: Int?,
         daysSincePIRLastActive: Int?) {
        self.statisticsStore = statisticsStore
        self.operatingSystemVersion = operatingSystemVersion
        self.appVersion = appVersion
        self.hardwareModel = hardwareModel
        self.subscription = subscription
        self.daysSinceVPNActivated = daysSinceVPNActivated
        self.daysSinceVPNLastActive = daysSinceVPNLastActive
        self.daysSincePIRActivated = daysSincePIRActivated
        self.daysSincePIRLastActive = daysSincePIRLastActive
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func buildSurveyURL(from originalURLString: String) -> URL? {
        guard var components = URLComponents(string: originalURLString) else {
            assertionFailure("Could not build components from survey URL")
            return URL(string: originalURLString)
        }

        var queryItems = components.queryItems ?? []

        for parameter in SurveyURLParameters.allCases {
            switch parameter {
            case .atb:
                if let atb = statisticsStore.atb {
                    queryItems.append(queryItem(parameter: parameter, value: atb))
                }
            case .atbVariant:
                if let variant = statisticsStore.variant {
                    queryItems.append(queryItem(parameter: parameter, value: variant))
                }
            case .macOSVersion:
                queryItems.append(queryItem(parameter: parameter, value: operatingSystemVersion))
            case .appVersion:
                queryItems.append(queryItem(parameter: parameter, value: appVersion))
            case .hardwareModel:
                if let hardwareModel = hardwareModel {
                    queryItems.append(queryItem(parameter: parameter, value: hardwareModel))
                }
            case .vpnFirstUsed:
                if let daysSinceVPNActivated {
                    queryItems.append(queryItem(parameter: parameter, value: daysSinceVPNActivated))
                }
            case .vpnLastUsed:
                if let daysSinceVPNLastActive {
                    queryItems.append(queryItem(parameter: parameter, value: daysSinceVPNLastActive))
                }
            case .pirFirstUsed:
                if let daysSincePIRActivated {
                    queryItems.append(queryItem(parameter: parameter, value: daysSincePIRActivated))
                }
            case .pirLastUsed:
                if let daysSincePIRLastActive {
                    queryItems.append(queryItem(parameter: parameter, value: daysSincePIRLastActive))
                }
            case .privacyProStatus:
                if let privacyProStatus = subscription?.status {
                    switch privacyProStatus {
                    case .autoRenewable: queryItems.append(queryItem(parameter: parameter, value: "auto_renewable"))
                    case .notAutoRenewable: queryItems.append(queryItem(parameter: parameter, value: "not_auto_renewable"))
                    case .gracePeriod: queryItems.append(queryItem(parameter: parameter, value: "grace_period"))
                    case .inactive: queryItems.append(queryItem(parameter: parameter, value: "inactive"))
                    case .expired: queryItems.append(queryItem(parameter: parameter, value: "expired"))
                    case .unknown: queryItems.append(queryItem(parameter: parameter, value: "unknown"))
                    }
                }
            case .privacyProPurchasePlatform:
                if let privacyProPurchasePlatform = subscription?.platform {
                    switch privacyProPurchasePlatform {
                    case .apple: queryItems.append(queryItem(parameter: parameter, value: "apple"))
                    case .google: queryItems.append(queryItem(parameter: parameter, value: "google"))
                    case .stripe: queryItems.append(queryItem(parameter: parameter, value: "stripe"))
                    case .unknown: queryItems.append(queryItem(parameter: parameter, value: "unknown"))
                    }
                }
            case .privacyProBillingPeriod:
                if let privacyProBillingPeriod = subscription?.billingPeriod {
                    switch privacyProBillingPeriod {
                    case .monthly: queryItems.append(queryItem(parameter: parameter, value: "monthly"))
                    case .yearly: queryItems.append(queryItem(parameter: parameter, value: "yearly"))
                    case .unknown: queryItems.append(queryItem(parameter: parameter, value: "unknown"))
                    }
                }
            case .privacyProDaysSincePurchase:
                if let startedAt = subscription?.startedAt, let daysSincePurchase = daysSince(date: startedAt) {
                    queryItems.append(queryItem(parameter: parameter, value: daysSincePurchase))
                }
            case .privacyProDaysUntilExpiration:
                if let expiresOrRenewsAt = subscription?.expiresOrRenewsAt, let daysUntilExpiry = daysSince(date: expiresOrRenewsAt) {
                    queryItems.append(queryItem(parameter: parameter, value: daysUntilExpiry))
                }
            }
        }

        components.queryItems = queryItems

        return components.url
    }

    private func queryItem(parameter: SurveyURLParameters, value: String) -> URLQueryItem {
        let urlAllowed: CharacterSet = .alphanumerics.union(.init(charactersIn: "-._~"))
        let sanitizedValue = value.addingPercentEncoding(withAllowedCharacters: urlAllowed)
        return URLQueryItem(name: parameter.rawValue, value: sanitizedValue)
    }

    private func queryItem(parameter: SurveyURLParameters, value: Int) -> URLQueryItem {
        return URLQueryItem(name: parameter.rawValue, value: String(describing: value))
    }

    private func daysSince(date storedDate: Date) -> Int? {
        if let days = Calendar.current.dateComponents([.day], from: storedDate, to: Date()).day {
            return abs(days)
        }

        return nil
    }

}
