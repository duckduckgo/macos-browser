//
//  PixelTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

class PixelExperimentTests: XCTestCase {

    var now = Date()
    var logic: PixelExperimentLogic {
        PixelExperiment.logic
    }
    var cohort: PixelExperiment! {
        logic.cohort
    }

    lazy var container: NSPersistentContainer = {
        CoreData.createInMemoryPersistentContainer(modelName: "PixelDataModel", bundle: Bundle(for: PixelData.self))
    }()
    var context: NSManagedObjectContext!
    private var _store: LocalPixelDataStore<PixelData>?
    var store: LocalPixelDataStore<PixelData> {
        if let store = _store {
            return store
        }
        context = container.newBackgroundContext()
        let store = LocalPixelDataStore(context: context, updateModel: PixelData.update)
        _store = store
        return store
    }

    override func setUp() {
        super.setUp()
        now = Date()
        PixelExperiment.logic = PixelExperimentLogic(now: { [unowned self] in
            self.now
        })
        logic.cleanup()
    }

    override func tearDown() {
        logic.cleanup()
        Pixel.tearDown()
        _store = nil
    }

    func testWhenNotInstalledThenCohortIsNill() {
        XCTAssertNil(logic.cohort)
        Pixel.setUp { _ in
            XCTFail("shouldn‘t fire pixels")
        }

        PixelExperiment.fireEnrollmentPixel()
        PixelExperiment.fireFirstSerpPixel()
        PixelExperiment.fireDay21To27SerpPixel()
        PixelExperiment.fireSetAsDefaultInitialPixel()
    }

    func testWhenNoCohort_NoEnrollmentPixelFired() {
        Pixel.firstLaunchDate = now
        PixelExperiment.install()

        Pixel.setUp(store: self.store) { _ in
            XCTFail("shouldn‘t fire pixels")
        }

        PixelExperiment.fireEnrollmentPixel()
    }

    func testEnrollmentPixel() {
        let e = expectation(description: "pixel fired")
        Pixel.setUp(store: self.store) { [unowned self] event in
            XCTAssertEqual(event, .launchInitial(cohort: cohort!.rawValue))
            e.fulfill()
        }

        Pixel.firstLaunchDate = now
        PixelExperiment.install()
        _=PixelExperiment.cohort

        PixelExperiment.fireEnrollmentPixel()
        // only initial is set
        PixelExperiment.fireEnrollmentPixel()
        now = now.adding(.days(5))
        PixelExperiment.fireEnrollmentPixel()

        waitForExpectations(timeout: 0)
    }

    func testFirstSerpPixel() {
        let e = expectation(description: "enrollment pixel fired")
        let e2 = expectation(description: "serp pixel fired")
        Pixel.setUp(store: self.store) { [unowned self] event in
            switch event {
            case .launchInitial(cohort: cohort.rawValue):
                e.fulfill()
            case .serpInitial(cohort: cohort.rawValue):
                e2.fulfill()
            default:
                XCTFail("unexpected \(event)")
            }
        }

        Pixel.firstLaunchDate = now
        PixelExperiment.install()
        _=PixelExperiment.cohort

        PixelExperiment.fireFirstSerpPixel()
        // only initial is set
        PixelExperiment.fireFirstSerpPixel()
        now = now.adding(.days(5))
        PixelExperiment.fireFirstSerpPixel()

        waitForExpectations(timeout: 0)
    }

    func testDay21SerpPixel() {
        let enrollment = expectation(description: "first pixel fired")
        var e: XCTestExpectation!
        Pixel.setUp(store: self.store) { [unowned self] event in
            switch event {
            case .launchInitial(cohort: cohort.rawValue):
                enrollment.fulfill()
            case .serpDay21to27(cohort: cohort.rawValue):
                e.fulfill()
            default:
                XCTFail("unexpected \(event)")
            }
        }

        let start = now
        Pixel.firstLaunchDate = start
        PixelExperiment.install()
        _=PixelExperiment.cohort

        // only enrollment should fire
        PixelExperiment.fireDay21To27SerpPixel()
        waitForExpectations(timeout: 0)

        // shouldn‘t fire after 20 days
        now = Calendar.current.date(byAdding: .day, value: 20, to: start)!
        PixelExperiment.fireDay21To27SerpPixel()

        // should fire after 21 days
        e = expectation(description: "21d pixel fired")
        now = Calendar.current.date(byAdding: .day, value: 21, to: start)!
        PixelExperiment.fireDay21To27SerpPixel()
        waitForExpectations(timeout: 0)

        // shouldn‘t fire after 26 days (only initial)
        now = Calendar.current.date(byAdding: .day, value: 26, to: start)!
        PixelExperiment.fireDay21To27SerpPixel()

        // shouldn‘t fire after 27 days
        now = Calendar.current.date(byAdding: .day, value: 27, to: start)!
        PixelExperiment.fireDay21To27SerpPixel()
    }

    func testDay27SerpPixel() {
        let enrollment = expectation(description: "first pixel fired")
        var e: XCTestExpectation!
        Pixel.setUp(store: self.store) { [unowned self] event in
            switch event {
            case .launchInitial(cohort: cohort.rawValue):
                enrollment.fulfill()
            case .serpDay21to27(cohort: cohort.rawValue):
                e.fulfill()
            default:
                XCTFail("unexpected \(event)")
            }
        }

        let start = now
        Pixel.firstLaunchDate = start
        PixelExperiment.install()
        _=PixelExperiment.cohort

        // only enrollment should fire
        PixelExperiment.fireDay21To27SerpPixel()
        waitForExpectations(timeout: 0)

        // shouldn‘t fire after 20 days
        now = Calendar.current.date(byAdding: .day, value: 20, to: start)!
        PixelExperiment.fireDay21To27SerpPixel()

        // should fire after 26 days
        e = expectation(description: "27d pixel fired")
        now = Calendar.current.date(byAdding: .day, value: 27, to: start)!
        PixelExperiment.fireDay21To27SerpPixel()
        waitForExpectations(timeout: 0)

        // shouldn‘t fire after 27 days
        now = Calendar.current.date(byAdding: .day, value: 28, to: start)!
        PixelExperiment.fireDay21To27SerpPixel()
    }

    func testDay28SerpPixel() {
        let enrollment = expectation(description: "first pixel fired")
        Pixel.setUp(store: self.store) { [unowned self] event in
            switch event {
            case .launchInitial(cohort: cohort.rawValue):
                enrollment.fulfill()
            default:
                XCTFail("unexpected \(event)")
            }
        }

        let start = now
        Pixel.firstLaunchDate = start
        PixelExperiment.install()
        _=PixelExperiment.cohort

        // only enrollment should fire
        PixelExperiment.fireDay21To27SerpPixel()
        waitForExpectations(timeout: 0)

        // shouldn‘t fire after 28 days
        now = Calendar.current.date(byAdding: .day, value: 28, to: start)!
        PixelExperiment.fireDay21To27SerpPixel()
    }

}
