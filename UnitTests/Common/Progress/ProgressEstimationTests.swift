//
//  ProgressEstimationTests.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

final class ProgressEstimationTests: XCTestCase {
    typealias Event = LoadingProgressView.ProgressEvent

    let milestones = [
        Event(progress: 0.25, interval: 0.0),
        Event(progress: 0.40, interval: 3.0),
        Event(progress: 0.65, interval: 15.0),
        Event(progress: 0.80, interval: 5.0),
        Event(progress: 0.85, interval: 10.0),
        Event(progress: 1.00, interval: 20.0)
    ]

    func testWhenProgressIsStartedEstimationIsInitial() {
        let event = Event.nextStep(for: 0.0, lastProgressEvent: nil, milestones: milestones)

        XCTAssertEqual(event, Event(progress: milestones[0].progress, interval: LoadingProgressView.Constants.animationDuration))
    }

    func testWhenProgressIsFinishedThenNoNextStep() {
        let event = Event.nextStep(for: 1.0, lastProgressEvent: Event(progress: 0.8, interval: 1.1), milestones: milestones)

        XCTAssertNil(event)
    }

    func testNextEstimatedEventMatchesNextMilestone() {
        var sum: CFTimeInterval = 0.0
        for (idx, milestone) in milestones[..<milestones.index(before: milestones.endIndex)].enumerated() {
            sum += milestone.interval
            let event = Event.nextStep(for: milestone.progress,
                                       lastProgressEvent: Event(progress: milestone.progress, interval: sum),
                                       milestones: milestones)

            XCTAssertEqual(event, milestones[idx + 1])
        }
    }

    func testWhenProgressMovesFasterEstimationIsShorter() {
        let event = Event.nextStep(for: 0.65, lastProgressEvent: Event(progress: 0.65, interval: 18.0 / 9.0), milestones: milestones)

        XCTAssertEqual(event, Event(progress: 0.8, interval: 5.0 / 9.0))
    }

    func testWhenProgressMovesFasterEstimationIsShorter2() {
        let event = Event.nextStep(for: 0.7, lastProgressEvent: Event(progress: 0.5, interval: 5.0), milestones: milestones)

        XCTAssertEqual(event?.progress, 0.8)
        let expectedInterval = (5.0 * 0.666 /* 33% passed from 0.6 to 0.7 */)
            * (5.0 / 9.0 /* expected (3.0 + 40% of 15.0 = 9) passed in actual 5 sec */ )
        XCTAssertEqual(Int(expectedInterval * 100), Int(event!.interval * 100))
    }

    func testWhenProgressMovesTooFastEstimationIsNotTooShort() {
        let event = Event.nextStep(for: 0.85, lastProgressEvent: Event(progress: 0.65, interval: 18.0 / 11.0), milestones: milestones)

        XCTAssertEqual(event, Event(progress: 1.0, interval: milestones.last!.interval * LoadingProgressView.Constants.minMultiplier))
    }

    func testWhenProgressMovesSlowerEstimationIsLonger() {
        let event = Event.nextStep(for: 0.65, lastProgressEvent: Event(progress: 0.65, interval: 18.0 * 9.0), milestones: milestones)

        XCTAssertEqual(event, Event(progress: 0.8, interval: 5.0 * 9.0))
    }

    func testWhenProgressMovesSlowerEstimationIsLonger2() {
        let event = Event.nextStep(for: 0.9, lastProgressEvent: Event(progress: 0.7, interval: 60.0), milestones: milestones)

        XCTAssertEqual(event?.progress, 1.0)
        let expectedInterval = (20.0 * 0.666 /* 33% passed from 0.0.85 to 0.9 */)
            * (60.0 / 19.65 /* expected (18.0 + 33% of 5.0 ~= 19.65) passed in actual 60 sec */ )
        XCTAssertEqual(Int(expectedInterval * 100), Int(event!.interval * 100))
    }

    func testWhenProgressMovesTooSlowEstimationIsNotTooLong() {
        let event = Event.nextStep(for: 0.4, lastProgressEvent: Event(progress: 0.3, interval: 180), milestones: milestones)

        XCTAssertEqual(event, Event(progress: 0.65, interval: 150.0))
    }

    func testWhenNoProgressEventsEstimationIsDefault() {
        let event = Event.nextStep(for: 0.85, lastProgressEvent: nil, milestones: milestones)

        XCTAssertEqual(event, Event(progress: 1.0, interval: milestones.last!.interval))
    }

}
