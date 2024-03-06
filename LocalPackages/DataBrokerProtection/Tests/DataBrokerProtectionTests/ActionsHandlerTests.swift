//
//  ActionsHandlerTests.swift
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
@testable import DataBrokerProtection

final class ActionsHandlerTests: XCTestCase {

    func testWhenStepHasNoActions_thenNilIsReturned() {
        let step = Step(type: .scan, actions: [Action]())
        let sut = ActionsHandler(step: step)

        XCTAssertNil(sut.nextAction())
    }

    func testWhenNextStepDoesNotFindAnyMoreActions_thenNilIsReturned() {
        let firstAction = NavigateAction(id: "navigate1", actionType: .navigate, url: "url", ageRange: [String](), dataSource: nil)
        let secondAction = NavigateAction(id: "navigate2", actionType: .navigate, url: "url", ageRange: [String](), dataSource: nil)
        let step = Step(type: .scan, actions: [firstAction, secondAction])
        let sut = ActionsHandler(step: step)

        _ = sut.nextAction() // Returns the first action
        _ = sut.nextAction() // Returns the second action

        XCTAssertNil(sut.nextAction())
    }

    func testWhenNextStepFindsAnAction_thenThatNextActionIsReturned() {
        let firstAction = NavigateAction(id: "navigate1", actionType: .navigate, url: "url", ageRange: [String](), dataSource: nil)
        let secondAction = NavigateAction(id: "navigate2", actionType: .navigate, url: "url", ageRange: [String](), dataSource: nil)
        let step = Step(type: .scan, actions: [firstAction, secondAction])
        let sut = ActionsHandler(step: step)

        _ = sut.nextAction() // Returns the first action
        let action = sut.nextAction() // Returns the second and last action

        XCTAssertEqual(action?.id, secondAction.id)
    }

}
