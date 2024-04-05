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
import PixelKit

enum PixelExperiment: String, CaseIterable {

    static var logic = PixelExperimentLogic()

    /// When `cohort` is accessed for the first time after the experiment is installed with `install()`,
    ///  allocate and return a cohort.  Subsequently, return the same cohort.
    static var cohort: PixelExperiment? {
        logic.cohort
    }

    static var isExperimentInstalled: Bool {
        return logic.isInstalled
    }

    static var allocatedCohortDoesNotMatchCurrentCohorts: Bool {
        guard let allocatedCohort = logic.allocatedCohort else { return false }
        if PixelExperiment(rawValue: allocatedCohort) == nil {
            return true
        }
        return false
    }

    /// Enables this experiment for new users when called from the new installation path.
    static func install() {
        logic.install()
    }

    static func cleanup() {
        logic.cleanup()
    }

    // These are the variants. Rename or add/remove them as needed.  If you change the string value
    //  remember to keep it clear for privacy triage.
    case control
}

/// These functions contain the business logic for determining if the pixel should be fired or not.
extension PixelExperiment {

    static func fireEnrollmentPixel() {
        logic.fireEnrollmentPixel()
    }

    static func fireFirstSerpPixel() {
        logic.fireFirstSerpPixel()
    }

    static func fireDay21To27SerpPixel() {
        logic.fireDay21To27SerpPixel()
    }

}

final internal class PixelExperimentLogic {

    private let now: () -> Date

    var cohort: PixelExperiment? {
        guard isInstalled else { return nil }

        if let allocatedCohort,
           // if the stored cohort doesn't match, allocate a new one
           let cohort = PixelExperiment(rawValue: allocatedCohort) {
            return cohort
        }

        // For now, just use equal distribution of all cohorts.
        let cohort = PixelExperiment.allCases.randomElement()!
        allocatedCohort = cohort.rawValue
        enrollmentDate = now()
        fireEnrollmentPixel()
        return cohort
    }

    @UserDefaultsWrapper(key: .pixelExperimentInstalled, defaultValue: false)
    var isInstalled: Bool

    @UserDefaultsWrapper(key: .pixelExperimentCohort, defaultValue: nil)
    var allocatedCohort: String?

    @UserDefaultsWrapper(key: .pixelExperimentEnrollmentDate, defaultValue: nil)
    private var enrollmentDate: Date?

    private var daysSinceEnrollment: Int {
        guard let enrollmentDate else { return 0 }
        let diff = now().timeIntervalSince1970 - enrollmentDate.timeIntervalSince1970
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

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func install() {
        isInstalled = true
    }

    // You'll need additional pixels for your experiment.  Pass the cohort as a parameter.
    func fireEnrollmentPixel() {
        // You'll probably need this at least.
    }

    // Often used
    func fireFirstSerpPixel() {
        guard allocatedCohort != nil, let cohort else { return }
        PixelKit.fire(GeneralPixel.serpInitial(cohort: cohort.rawValue), frequency: .unique, includeAppVersionParameter: false)
    }

    // Often used for retention experiments
    func fireDay21To27SerpPixel() {
        guard allocatedCohort != nil, let cohort else { return }

        DispatchQueue.main.async {
            let now = self.now()
            if now >= AppDelegate.firstLaunchDate.adding(.days(21)) && now <= AppDelegate.firstLaunchDate.adding(.days(27)) {
                PixelKit.fire(GeneralPixel.serpDay21to27(cohort: cohort.rawValue), frequency: .unique, includeAppVersionParameter: false)
            }
        }
    }

    func cleanup() {
        isInstalled = false
        allocatedCohort = nil
        enrollmentDate = nil
        firedPixelsStorage = []
    }

}
