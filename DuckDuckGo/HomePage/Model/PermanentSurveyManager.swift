//
//  PermanentSurveyManager.swift
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

import Foundation
import BrowserServicesKit
import AppKit

struct Survey: Equatable {
    let url: URL
    let isLocalized: Bool
    let firstDay: Int
    let lastDay: Int
    let sharePercentage: Int
}

protocol SurveyManager {
    var survey: Survey? { get }
}

struct PermanentSurveyManager: SurveyManager {
    private let surveySettings: [String: Any]?
    private let userDecider: InternalUserDecider
    var survey: Survey? {
        guard isEnabled == true else { return nil }
        guard let url else { return nil }
        return Survey(
            url: url,
            isLocalized: isLocalised,
            firstDay: firstDay,
            lastDay: lastDay,
            sharePercentage: sharePercentage)
    }

    init(privacyConfigurationManager: PrivacyConfigurationManaging = AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager) {
        let newTabContinueSetUpSettings = privacyConfigurationManager.privacyConfig.settings(for: .newTabContinueSetUp)
        self.surveySettings = newTabContinueSetUpSettings["permanentSurvey"] as? [String: Any]
        self.userDecider = NSApp.delegateTyped.internalUserDecider
    }

    private var isEnabled: Bool {
        if let state =  surveySettings?["state"] as? String {
            if state == "enabled" {
                return true
            }
            if state == "internal" && userDecider.isInternalUser {
                return true
            }
        }
        return false
    }

    private var isLocalised: Bool {
        if let state =  surveySettings?["localization"] as? String {
            if state == "enabled" {
                return true
            }
        }
        return false
    }

    private var url: URL? {
        if let urlString =  surveySettings?["url"] as? String {
            return URL(string: urlString)
        }
        return nil
    }

    private var firstDay: Int {
        return surveySettings?["firstDay"] as? Int ?? 0
    }

    private var lastDay: Int {
        return surveySettings?["lastDay"] as? Int ?? 365
    }

    private var sharePercentage: Int {
        return surveySettings?["sharePercentage"] as? Int ?? 0
    }
}
