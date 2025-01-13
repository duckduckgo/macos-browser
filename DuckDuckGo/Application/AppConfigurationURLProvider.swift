//
//  AppConfigurationURLProvider.swift
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

import Configuration
import Foundation
import BrowserServicesKit

struct AppConfigurationURLProvider: ConfigurationURLProviding {

    // MARK: - Debug

    internal init(privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager,
                  featureFlagger: FeatureFlagger = Application.appDelegate.featureFlagger,
                  customPrivacyConfiguration: URL? = nil) {
        self.init(privacyConfigurationManager: privacyConfigurationManager, featureFlagger: featureFlagger)
        if let customPrivacyConfiguration {
            // Overwrite custom privacy configuration if provided
            self.customPrivacyConfiguration = customPrivacyConfiguration.absoluteString
        }
        // Otherwise use the default or already stored custom configuration
    }

    @UserDefaultsWrapper(key: .customConfigurationUrl, defaultValue: nil)
    private var customPrivacyConfiguration: String?

    private var customPrivacyConfigurationUrl: URL? {
        if let customPrivacyConfiguration {
            return URL(string: customPrivacyConfiguration)
        }
        return nil
    }

    mutating func resetToDefaultConfigurationUrl() {
        self.customPrivacyConfiguration = nil
    }

    // MARK: - Main

    var privacyConfigurationManager: PrivacyConfigurationManaging
    var featureFlagger: FeatureFlagger

    public enum Constants {
        public static let baseTdsURL: String = "https://staticcdn.duckduckgo.com/trackerblocking/v6/"
    }

    init (privacyConfigurationManager: PrivacyConfigurationManaging = ContentBlocking.shared.privacyConfigurationManager,
          featureFlagger: FeatureFlagger = Application.appDelegate.featureFlagger) {
        self.privacyConfigurationManager = privacyConfigurationManager
        self.featureFlagger = featureFlagger
    }

    func url(for configuration: Configuration) -> URL {
        // URLs for privacyConfiguration and trackerDataSet shall match the ones in update_embedded.sh. 
        // Danger checks that the URLs match on every PR. If the code changes, the regex that Danger uses may need an update.
        switch configuration {
        case .bloomFilterBinary: return URL(string: "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom.bin")!
        case .bloomFilterSpec: return URL(string: "https://staticcdn.duckduckgo.com/https/https-mobile-v2-bloom-spec.json")!
        case .bloomFilterExcludedDomains: return URL(string: "https://staticcdn.duckduckgo.com/https/https-mobile-v2-false-positives.json")!
        case .privacyConfiguration: return customPrivacyConfigurationUrl ?? URL(string: "https://staticcdn.duckduckgo.com/trackerblocking/config/v4/macos-config.json")!
        case .surrogates: return URL(string: "https://staticcdn.duckduckgo.com/surrogates.txt")!
        case .trackerDataSet:
            print("trackerRadar  \(trackerDataURL())")
            return trackerDataURL()
        // In archived repo, to be refactored shortly (https://staticcdn.duckduckgo.com/useragents/social_ctp_configuration.json)
        case .remoteMessagingConfig: return RemoteMessagingClient.Constants.endpoint
        }
    }

    private func trackerDataURL() -> URL {
        for experimentType in TdsExperimentType.allCases {
            if let cohort = featureFlagger.getCohortIfEnabled(for: experimentType.experiment) as? TdsNextExperimentFlag.Cohort {
                let url = trackerDataURLfromConfiguration(subfeature: experimentType.subfeature, cohort: cohort)
                return url ?? URL(string: "https://staticcdn.duckduckgo.com/trackerblocking/v6/current/macos-tds.json")!
            }
        }
        return URL(string: "https://staticcdn.duckduckgo.com/trackerblocking/v6/current/macos-tds.json")!
    }

    private func trackerDataURLfromConfiguration(subfeature: any PrivacySubfeature, cohort: TdsNextExperimentFlag.Cohort) -> URL? {
        guard let settings = privacyConfigurationManager.privacyConfig.settings(for: subfeature) else { return nil }
        if let jsonData = settings.data(using: .utf8) {
            do {
                if let settings = try JSONSerialization.jsonObject(with: jsonData) as? [String: String],
                   let controlUrl = settings["controlUrl"],
                   let treatmentUrl = settings["treatmentUrl"] {
                    switch cohort {
                    case .control:
                        return URL(string: Constants.baseTdsURL + controlUrl)
                    case .treatment:
                        return URL(string: Constants.baseTdsURL + treatmentUrl)
                    }
                }
            } catch {
                print("Failed to parse JSON: \(error)")
                return nil
            }
        }
        return nil
    }

}

public enum TdsExperimentType: Int, CaseIterable {
    case baseline
    case feb24
    case mar24
    case apr24
    case may24
    case jun24
    case jul24
    case aug24
    case sep24
    case oct24
    case nov24
    case dec24

    var experiment: any FeatureFlagExperimentDescribing {
        TdsNextExperimentFlag(subfeature: self.subfeature)
    }

    var subfeature: any PrivacySubfeature {
        switch self {
        case .baseline:
            ContentBlockingSubfeature.tdsNextExperimentBaseline
        case .feb24:
            ContentBlockingSubfeature.tdsNextExperimentFeb24
        case .mar24:
            ContentBlockingSubfeature.tdsNextExperimentMar24
        case .apr24:
            ContentBlockingSubfeature.tdsNextExperimentApr24
        case .may24:
            ContentBlockingSubfeature.tdsNextExperimentMay24
        case .jun24:
            ContentBlockingSubfeature.tdsNextExperimentJun24
        case .jul24:
            ContentBlockingSubfeature.tdsNextExperimentJul24
        case .aug24:
            ContentBlockingSubfeature.tdsNextExperimentAug24
        case .sep24:
            ContentBlockingSubfeature.tdsNextExperimentSep24
        case .oct24:
            ContentBlockingSubfeature.tdsNextExperimentOct24
        case .nov24:
            ContentBlockingSubfeature.tdsNextExperimentNov24
        case .dec24:
            ContentBlockingSubfeature.tdsNextExperimentDec24
        }
    }

}

public struct TdsNextExperimentFlag: FeatureFlagExperimentDescribing {
    public var rawValue: String
    public var source: FeatureFlagSource

    init(subfeature: any PrivacySubfeature) {
        self.source = .remoteReleasable(.subfeature(subfeature))
        self.rawValue = subfeature.rawValue
    }

    public typealias CohortType = Cohort

    public enum Cohort: String, FlagCohort {
        case control
        case treatment
    }
}
