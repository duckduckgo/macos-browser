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
import BrowserServicesKit

final class SurveyURLBuilder {

    enum SurveyURLParameters: String, CaseIterable {
        case atb = "atb"
        case atbVariant = "var"
        case macOSVersion = "osv"
        case appVersion = "ddgv"
        case hardwareModel = "mo"

        case vpnFirstUsed = "vpn_first_used"
        case vpnLastUsed = "vpn_last_used"
        case pirFirstUsed = "pir_first_used"
        case pirLastUsed = "pir_last_used"
    }

    private let statisticsStore: StatisticsStore
    private let operatingSystemVersion: String
    private let appVersion: String
    private let hardwareModel: String?
    private let daysSinceVPNActivated: Int?
    private let daysSinceVPNLastActive: Int?
    private let daysSincePIRActivated: Int?
    private let daysSincePIRLastActive: Int?

    init(statisticsStore: StatisticsStore,
         operatingSystemVersion: String,
         appVersion: String,
         hardwareModel: String?,
         daysSinceVPNActivated: Int?,
         daysSinceVPNLastActive: Int?,
         daysSincePIRActivated: Int?,
         daysSincePIRLastActive: Int?) {
        self.statisticsStore = statisticsStore
        self.operatingSystemVersion = operatingSystemVersion
        self.appVersion = appVersion
        self.hardwareModel = hardwareModel
        self.daysSinceVPNActivated = daysSinceVPNActivated
        self.daysSinceVPNLastActive = daysSinceVPNLastActive
        self.daysSincePIRActivated = daysSincePIRActivated
        self.daysSincePIRLastActive = daysSincePIRLastActive
    }

    // swiftlint:disable:next cyclomatic_complexity
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
            }
        }

        components.queryItems = queryItems

        return components.url
    }

    func buildSurveyURLWithPasswordsCountSurveyParameter(from originalURLString: String) -> URL? {
        let surveyURLWithParameters = buildSurveyURL(from: originalURLString)

        guard let surveyURLWithParametersString = surveyURLWithParameters?.absoluteString,
                var components = URLComponents(string: surveyURLWithParametersString),
                let bucket = passwordsCountBucket() else {
            return surveyURLWithParameters
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "saved_passwords", value: bucket))

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

    private func passwordsCountBucket() -> String? {
        guard let secureVault = try? AutofillSecureVaultFactory.makeVault(reporter: SecureVaultReporter.shared),
              let bucket = try? secureVault.accountsCountBucket() else {
            return nil
        }

        return bucket
    }

}
