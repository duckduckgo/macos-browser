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
import Common
import AppKit

protocol SurveyManager {
    var isSurveyAvailable: Bool { get }
    var url: URL? { get }
    static var title: String { get }
    static var body: String { get }
    static var actionTitle: String { get }
}

struct PermanentSurveyManager: SurveyManager {
    static var title: String = "Help Us Improve"
    static var body: String = "Take our short survey and help us build the best browser."
    static var actionTitle: String = "Share Your Thoughts"

    @UserDefaultsWrapper(key: .firstLaunchDate, defaultValue: Calendar.current.date(byAdding: .month, value: -1, to: Date())!)
    private var firstLaunchDate: Date

    @UserDefaultsWrapper(key: .homePageUserInSurveyShare, defaultValue: nil)
    private var isUserRegisteredInSurveyShare: Bool?

    private let surveySettings: [String: Any]?
    private let userDecider: InternalUserDecider
    private let randomNumberGenerator: RandomNumberGenerating
    private let statisticsStore: StatisticsStore

    init(privacyConfigurationManager: PrivacyConfigurationManaging = AppPrivacyFeatures.shared.contentBlocking.privacyConfigurationManager,
         randomNumberGenerator: RandomNumberGenerating = RandomNumberGenerator(),
         statisticsStore: StatisticsStore = LocalStatisticsStore()) {
        let newTabContinueSetUpSettings = privacyConfigurationManager.privacyConfig.settings(for: .newTabContinueSetUp)
        self.surveySettings = newTabContinueSetUpSettings["permanentSurvey"] as? [String: Any]
        self.userDecider = NSApp.delegateTyped.internalUserDecider
        self.randomNumberGenerator = randomNumberGenerator
        self.statisticsStore = statisticsStore
    }

    public var isSurveyAvailable: Bool {
        let firstSurveyDayDate = Calendar.current.date(byAdding: .weekday, value: -firstDay, to: Date())!
        let lastSurveyDayDate = Calendar.current.date(byAdding: .weekday, value: -lastDay, to: Date())!
        let rightLocale = isLocalized ? true : Bundle.main.preferredLocalizations.first == "en"

        return
            isEnabled &&
            firstLaunchDate >= lastSurveyDayDate &&
            firstLaunchDate <= firstSurveyDayDate &&
            rightLocale &&
            isUserInSurveyShare(sharePercentage)
    }

    public var url: URL? {
        guard let urlString =  surveySettings?["url"] as? String else { return nil }
        guard let url = URL(string: urlString) else { return nil }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        var newQueryItems: [URLQueryItem] = []
        if let atb = statisticsStore.atb {
            newQueryItems.append(URLQueryItem(name: "atb", value: atb))
        }
        if let variant = statisticsStore.variant {
            newQueryItems.append(URLQueryItem(name: "v", value: variant))
        }
        newQueryItems.append(URLQueryItem(name: "ddg", value: AppVersion.shared.versionNumber))
        newQueryItems.append(URLQueryItem(name: "macos", value: AppVersion.shared.majorAndMinorOSVersion))
        let oldQueryItems = components?.queryItems ?? []
        components?.queryItems = oldQueryItems + newQueryItems

        return components?.url ?? url
    }

    private func isUserInSurveyShare(_ share: Int) -> Bool {
        if isUserRegisteredInSurveyShare ?? false {
            return true
        }
        let randomNumber0To99 = randomNumberGenerator.random(in: 0..<100)
        isUserRegisteredInSurveyShare = randomNumber0To99 < share
        return isUserRegisteredInSurveyShare!
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

    private var isLocalized: Bool {
        if let state =  surveySettings?["localization"] as? String {
            if state == "enabled" {
                return true
            }
        }
        return false
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

public protocol RandomNumberGenerating {
    func random(in range: Range<Int>) -> Int
}

struct RandomNumberGenerator: RandomNumberGenerating {
    func random(in range: Range<Int>) -> Int {
        return Int.random(in: range)
    }
}
