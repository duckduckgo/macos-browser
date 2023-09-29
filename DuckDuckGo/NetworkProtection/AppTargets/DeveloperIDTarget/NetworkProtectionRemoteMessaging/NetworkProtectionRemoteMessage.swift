//
//  NetworkProtectionRemoteMessage.swift
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

struct NetworkProtectionRemoteMessage: Codable, Equatable, Hashable {

    enum SurveyURLParameters: String, CaseIterable {
        case atb = "atb"
        case atbVariant = "var"
        case daysSinceActivated = "delta"
        case macosVersion = "mv"
        case appVersion = "ddgv"
        case hardwareModel = "mo"
        case lastDayActive = "da"
    }

    let id: String
    let cardTitle: String
    let cardDescription: String
    let cardAction: String
    let daysSinceNetworkProtectionEnabled: Int?
    private let surveyURL: String?

    // swiftlint:disable:next cyclomatic_complexity
    func presentableSurveyURL(
        statisticsStore: StatisticsStore = LocalStatisticsStore(),
        activationDateStore: WaitlistActivationDateStore = DefaultWaitlistActivationDateStore(),
        operatingSystemVersion: String = ProcessInfo.processInfo.operatingSystemVersion.description,
        appVersion: String = AppVersion.shared.versionNumber,
        hardwareModel: String? = HardwareModel.model
    ) -> URL? {
        guard let surveyURL else {
            return nil
        }

        guard var components = URLComponents(string: surveyURL) else {
            return URL(string: surveyURL)
        }

        var queryItems = components.queryItems ?? []

        for parameter in SurveyURLParameters.allCases {
            switch parameter {
            case .atb:
                if let atb = statisticsStore.atb {
                    queryItems.append(URLQueryItem(name: parameter.rawValue, value: atb))
                }
            case .atbVariant:
                if let variant = statisticsStore.variant {
                    queryItems.append(URLQueryItem(name: parameter.rawValue, value: variant))
                }
            case .daysSinceActivated:
                if let daysSinceActivated = activationDateStore.daysSinceActivation() {
                    queryItems.append(URLQueryItem(name: parameter.rawValue, value: String(describing: daysSinceActivated)))
                }
            case .macosVersion:
                queryItems.append(URLQueryItem(name: parameter.rawValue, value: operatingSystemVersion))
            case .appVersion:
                queryItems.append(URLQueryItem(name: parameter.rawValue, value: appVersion))
            case .hardwareModel:
                if let hardwareModel = hardwareModel?.addingPercentEncoding(withAllowedCharacters: .alphanumerics) {
                    queryItems.append(URLQueryItem(name: parameter.rawValue, value: hardwareModel))
                }
            case .lastDayActive:
                if let lastDayActive = activationDateStore.daysSinceLastActive() {
                    queryItems.append(URLQueryItem(name: parameter.rawValue, value: String(describing: lastDayActive)))
                }
            }
        }

        components.queryItems = queryItems

        return components.url
    }
}
