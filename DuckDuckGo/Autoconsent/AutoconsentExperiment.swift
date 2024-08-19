//
//  AutoconsentExperiment.swift
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
import Common

enum AutoconsentFilterlistExperiment: String, CaseIterable {
    static var logic = AutoconsentExperimentLogic()
    static var cohort: AutoconsentFilterlistExperiment? {
        os_log("🚧 requesting CPM cohort", log: .autoconsent, type: .debug)
        return logic.experimentCohort
    }

    case control = "fc"
    case test = "ft"
}

final internal class AutoconsentExperimentLogic {
    var experimentCohort: AutoconsentFilterlistExperiment? {
        if let allocatedExperimentCohort,
           // if the stored cohort doesn't match, allocate a new one
           let cohort = AutoconsentFilterlistExperiment(rawValue: allocatedExperimentCohort)
        {
            os_log("🚧 existing CPM cohort: %s", log: .autoconsent, type: .debug, String(describing: cohort.rawValue))
            return cohort
        }
        let cohort = AutoconsentFilterlistExperiment.allCases.randomElement()!
        os_log("🚧 new CPM cohort: %s", log: .autoconsent, type: .debug, String(describing: cohort.rawValue))
        allocatedExperimentCohort = cohort.rawValue
        return cohort
    }

    @UserDefaultsWrapper(key: .autoconsentFilterlistExperimentCohort, defaultValue: nil)
    var allocatedExperimentCohort: String?
}
