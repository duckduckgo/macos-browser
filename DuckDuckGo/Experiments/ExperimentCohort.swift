//
//  Cohort.swift
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

// TODO store the date of allocation

///
/// Edit this cases to define the cohorts that users will be allocated to.  Update the list of pixels and the cohort will automatically be added to them
///
enum ExperimentCohort: String, CaseIterable {

    @UserDefaultsWrapper(key: .experimentCohort, defaultValue: nil)
    static var cohortStore: String?

    static var isAllocated: Bool {
        cohortStore != nil
    }

    static var allocated: ExperimentCohort {
        if let cohortStore, let cohort = ExperimentCohort(rawValue: cohortStore) {
            return cohort
        }

        let cohortIndex = Int.random(in: 0 ..< allCases.count)
        let cohort = allCases[cohortIndex]
        cohortStore = cohort.rawValue
        return cohort
    }

    static func reset() {
        cohortStore = nil
    }

    // Update this list of pixels to add the cohort to
    static let pixels: [Pixel.Event] = [
        .serp,
    ]

    // Keep this:
    case control

    // Change or add to these:
    case showBookmarkPrompt

}
