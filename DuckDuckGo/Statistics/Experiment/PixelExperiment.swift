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

enum PixelExperiment: String, CaseIterable {

    fileprivate static let logic = PixelExperimentLogic {
        Pixel.fire($0)
    }

    /// When `cohort` is accessed for the first time, allocate and return a cohort.  Subsequently, return the same cohort.
    static var cohort: PixelExperiment {
        logic.cohort
    }

    // These are the variants. Rename or add/remove them as needed.  If you change the string value
    //  remember to keep it clear for privacy triage.
    case control
    case showBookmarksBarPrompt = "variant1"

}

/// These functions contain the business logic for determining if the pixel should be fired or not.
extension PixelExperiment {

    static func fireEnrollmentPixel() {
        logic.fireEnrollmentPixel()
    }

    static func fireSearchOnDay4to8Pixel() {
        logic.fireSearchOnDay4to8Pixel()
    }

    static func fireBookmarksBarInteractionPixel() {
        logic.fireBookmarksBarInteractionPixel()
    }

}

final internal class PixelExperimentLogic {

    var cohort: PixelExperiment {
        if let allocatedCohort,
           // if the stored cohort doesn't match, allocate a new one
           let cohort = PixelExperiment(rawValue: allocatedCohort) {
            return cohort
        }

        // For now, just use equal distribution of all cohorts.
        let cohort = PixelExperiment.showBookmarksBarPrompt // PixelExperiment.allCases.randomElement()!
        allocatedCohort = cohort.rawValue
        enrollmentDate = Date()
        fireEnrollmentPixel()
        return cohort
    }

    @UserDefaultsWrapper(key: .pixelExperimentCohort, defaultValue: nil)
    var allocatedCohort: String?

    @UserDefaultsWrapper(key: .pixelExperimentEnrollmentDate, defaultValue: nil)
    var enrollmentDate: Date?

    private var daysSinceEnrollment: Int {
        guard let enrollmentDate else { return 0 }
        let diff = Date().timeIntervalSince1970 - enrollmentDate.timeIntervalSince1970
        let days = Int(diff / 60 / 60 / 24)
        return days
    }

    @UserDefaultsWrapper(key: .pixelExperimentFiredPixels, defaultValue: [])
    private var firedPixelsStorage: [String]

    private var firedPixels: Set<String> {
        get {
            Set<String>(firedPixelsStorage)
        }

        set {
            firedPixelsStorage = Array(newValue)
        }
    }

    private let fire: (Pixel.Event) -> Void

    init(fire: @escaping (Pixel.Event) -> Void) {
        self.fire = fire
    }

    func fireEnrollmentPixel() {
        guard allocatedCohort != nil else { return }
        if firedPixels.insert(Pixel.Event.bookmarksBarOnboardingEnrollment(cohort: "").name).inserted {
            fire(.bookmarksBarOnboardingEnrollment(cohort: cohort.rawValue))
        }
    }

    func fireSearchOnDay4to8Pixel() {
        guard allocatedCohort != nil else { return }
        guard 4...8 ~= daysSinceEnrollment else { return }
        if firedPixels.insert(Pixel.Event.bookmarksBarOnboardingSearched4to8days(cohort: "").name).inserted {
            fire(.bookmarksBarOnboardingSearched4to8days(cohort: cohort.rawValue))
        }
    }

    func fireBookmarksBarInteractionPixel() {
        guard allocatedCohort != nil else { return }
        if firedPixels.insert(Pixel.Event.bookmarksBarOnboardingFirstInteraction(cohort: "").name).inserted {
            fire(.bookmarksBarOnboardingFirstInteraction(cohort: cohort.rawValue))
        } else if 2...8 ~= daysSinceEnrollment && firedPixels.insert(Pixel.Event.bookmarksBarOnboardingInteraction2to8days(cohort: "").name).inserted {
            fire(.bookmarksBarOnboardingInteraction2to8days(cohort: cohort.rawValue))
        }
    }

    func reset() {
        allocatedCohort = nil
        enrollmentDate = nil
        firedPixelsStorage = []
    }

}
