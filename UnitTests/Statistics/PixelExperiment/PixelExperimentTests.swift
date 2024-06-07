//
//  PixelExperimentTests.swift
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
import PixelKit
import os.log
@testable import DuckDuckGo_Privacy_Browser

/*
 WARNING: This component doesn't work anymore, re-implementation needed
 https://app.asana.com/0/0/1207002879349166/f
 */

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
        PixelKit.tearDown()
        _store = nil
    }

    func testWhenNotInstalledThenCohortIsNill() {
        XCTAssertNil(logic.cohort)

        PixelKit.setUp(appVersion: "",
                       defaultHeaders: [:],
                       defaults: UserDefaults()) { _, _, _, _, _, _ in
            XCTFail("shouldn‘t fire pixels")
        }

        PixelExperiment.fireEnrollmentPixel()
        PixelExperiment.fireFirstSerpPixel()
        PixelExperiment.fireDay21To27SerpPixel()
    }

    func testWhenNoCohort_NoEnrollmentPixelFired() {
        DispatchQueue.main.async {
            AppDelegate.firstLaunchDate = self.now
            PixelExperiment.install()

            PixelKit.setUp(appVersion: "",
                           defaultHeaders: [:],
                           defaults: UserDefaults()) { _, _, _, _, _, _ in
                XCTFail("shouldn‘t fire pixels")
            }

            PixelExperiment.fireEnrollmentPixel()
        }
    }

    // See git history for fireFirstSerpPixel and fireDay21To27SerpPixel tests
}
