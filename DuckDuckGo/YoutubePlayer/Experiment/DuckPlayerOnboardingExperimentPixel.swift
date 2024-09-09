//
//  DuckPlayerOnboardingExperimentPixel.swift
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

// https://app.asana.com/0/72649045549333/1208088257884523/f
enum DuckPlayerOnboardingExperimentPixel: PixelKitEventV2 {

    case enrollmentPixel
    case weeklyUniqueView
    case modalAccept
    case modalReject

    var name: String {
        switch self {
        case .enrollmentPixel:
            "duckplayer_experiment_cohort_assign"
        case .weeklyUniqueView:
            "duckplayer_weekly-unique-view"
        case .modalAccept:
            "duckplayer_experiment_modal-accept"
        case .modalReject:
            "duckplayer_experiment_modal-reject"
        }
    }

    var parameters: [String: String]? {
        switch self {
        case .enrollmentPixel:
            return DuckPlayerOnboardingExperiment().getPixelParameters(date: false)
        case .weeklyUniqueView,
                .modalAccept,
                .modalReject:
            return DuckPlayerOnboardingExperiment().getPixelParameters()
        }
    }

    var error: (any Error)? {
        nil
    }
}
