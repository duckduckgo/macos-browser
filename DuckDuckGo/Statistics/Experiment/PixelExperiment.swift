//
//  PixelExperiment.swift
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

/// When `cohort` is accessed for the first time, allocate and return a cohort.  Subsequently, return the same cohort.
enum PixelExperiment: String, CaseIterable {

    static var cohort: PixelExperiment {
        if let allocatedCohort,
            // if the stored cohort doesn't match, allocate a new one
           let cohort = Self.init(rawValue: allocatedCohort) {
            return cohort
        }

        // For now, just use equal distribution of all cohorts.
        let cohort = allCases.randomElement()!
        allocatedCohort = cohort.rawValue
        enrollmentDate = Date().timeIntervalSince1970
        fireEnrollmentPixel()
        return cohort
    }

    @UserDefaultsWrapper(key: .pixelExperimentCohort, defaultValue: nil)
    fileprivate static var allocatedCohort: String?

    @UserDefaultsWrapper(key: .pixelExperimentEnrollmentDate, defaultValue: nil)
    fileprivate static var enrollmentDate: TimeInterval?

    fileprivate static var daysSinceEnrollment: Int {
        guard let enrollmentDate else { return 0 }
        let diff = enrollmentDate - Date().timeIntervalSince1970
        let days = Int(diff / 60 / 24)
        return days
    }

    private static var firedPixelsStorage = Set<String>()
    fileprivate static var firedPixels: Set<String> {
        get {
            firedPixelsStorage
        }

        set {
            firedPixelsStorage = newValue
        }
    }

    // These are the variants. Rename or add/remove them as needed.
    case control
    case showBookmarksBarPrompt = "variant1"

}

/// These functions contain the business logic for determining if the pixel should be fired or not.
extension PixelExperiment {

    static func fireEnrollmentPixel() {
        if firedPixels.insert(Pixel.Event.bookmarksBarOnboardingEnrollment(cohort: "").name).inserted {
            Pixel.fire(.bookmarksBarOnboardingEnrollment(cohort: cohort.rawValue))
        }
    }

    static func fireSearchOnDay4to8Pixel() {
        guard allocatedCohort != nil else { return }
        guard 4...8 ~= daysSinceEnrollment else { return }
        if firedPixels.insert(Pixel.Event.bookmarksBarOnboardingSearched4to8days(cohort: "").name).inserted {
            Pixel.fire(.bookmarksBarOnboardingSearched4to8days(cohort: cohort.rawValue))
        }
    }

    static func fireBookmarksBarInteractionPixel() {
        guard allocatedCohort != nil else { return }
        if firedPixels.insert(Pixel.Event.bookmarksBarOnboardingFirstInteraction(cohort: "").name).inserted {
            Pixel.fire(.bookmarksBarOnboardingFirstInteraction(cohort: cohort.rawValue))
        } else if 2...8 ~= daysSinceEnrollment && firedPixels.insert(Pixel.Event.bookmarksBarOnboardingInteraction2to8days(cohort: "").name).inserted {
            Pixel.fire(.bookmarksBarOnboardingInteraction2to8days(cohort: cohort.rawValue))
        }
    }

}
