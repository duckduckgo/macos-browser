//
//  NewTabSearchBoxExperimentPixel.swift
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
import PixelKit

/**
 * This enum keeps pixels related to New Tab Search Box experiment.
 *
 * > Related links:
 * [Privacy Triage](https://app.asana.com/0/69071770703008/1208554746029816/f)
 * [Detailed Pixels description](https://app.asana.com/0/72649045549333/1208549467638910/f)
 */
enum NewTabSearchBoxExperimentPixel: PixelKitEventV2 {

    case cohortAssigned(cohort: NewTabPageSearchBoxExperiment.Cohort, onboardingCohort: PixelExperiment?)
    case initialSearch(day: Int, count: Int, from: NewTabPageSearchBoxExperiment.SearchSource, cohort: NewTabPageSearchBoxExperiment.Cohort, onboardingCohort: PixelExperiment?)

    var name: String {
        switch self {
        case .cohortAssigned:
            return "m_mac_initial-search-day-1"
        case .initialSearch(let day, _, _, _, _):
            return "m_mac_initial-search-day-\(day)"
        }
    }

    var parameters: [String: String]? {
        switch self {
        case let .cohortAssigned(cohort, onboardingCohort):
            var parameters = [
                Parameters.count: "0",
                Parameters.cohort: cohort.rawValue
            ]
            if let onboardingCohort {
                parameters[Parameters.onboardingCohort] = onboardingCohort.rawValue
            }
            return parameters

        case let .initialSearch(_, count, from, cohort, onboardingCohort):
            var parameters = [
                Parameters.count: String(count),
                Parameters.from: from.rawValue,
                Parameters.cohort: cohort.rawValue
            ]
            if let onboardingCohort {
                parameters[Parameters.onboardingCohort] = onboardingCohort.rawValue
            }
            return parameters
        }
    }

    var error: (any Error)? {
        nil
    }

    enum Parameters {
        static let cohort = "cohort"
        static let count = "count"
        static let from = "from"
        static let onboardingCohort = "onboarding_cohort"
    }
}
