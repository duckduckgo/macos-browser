//
//  UserScriptsManagerTests.swift
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

import Foundation
import XCTest
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class UserScriptsManagerTests: XCTestCase {

    final class ScriptSourceProvidingSourceUpdater: ScriptSourceProviding {
        var sourceUpdatedSubject = PassthroughSubject<Void, Never>()
        var sourceUpdatedPublisher: AnyPublisher<Void, Never> {
            sourceUpdatedSubject.eraseToAnyPublisher()
        }

        func reload() {
            sourceUpdatedSubject.send( () )
        }

        var contentBlockerRulesSource: String { fatalError() }
        var contentBlockerSource: String { fatalError() }
    }

    func testWhenUserScriptsManagerInitializedUserScriptsAreLoadedAndStored() {
        let manager = UserScriptsManager(scriptSource: ScriptSourceProvidingSourceUpdater())

        var userScripts1: UserScripts!
        let c = manager.$userScripts.sink {
            guard userScripts1 == nil else { XCTFail("Should sink once"); return }
            userScripts1 = $0
        }

        let userScripts2 = manager.userScripts

        XCTAssertFalse(userScripts1.userScripts.isEmpty)
        XCTAssertTrue(userScripts1 === userScripts2)
        c.cancel()
    }

    func testWhenScriptSourceProvidingSourceUpdatedUserScriptsAreReloadedOnMainQueue() {
        let updater = ScriptSourceProvidingSourceUpdater()
        let manager = UserScriptsManager(scriptSource: updater)

        var userScripts1: UserScripts!
        var userScripts2: UserScripts!
        let e = expectation(description: "Should sink UserScripts twice")
        let c = manager.$userScripts.sink {
            dispatchPrecondition(condition: .onQueue(.main))

            if userScripts1 == nil {
                userScripts1 = $0
            } else {
                userScripts2 = $0
                e.fulfill()
            }
        }

        DispatchQueue.global().async {
            updater.reload()
        }

        waitForExpectations(timeout: 0.1)

        let userScripts3 = manager.userScripts

        // swiftlint:disable force_cast
        let set1 = Set(userScripts1.userScripts as! [NSObject])
        let set2 = Set(userScripts2.userScripts as! [NSObject])
        // swiftlint:enable force_cast

        XCTAssertNotEqual(set1, set2)
        XCTAssertFalse(userScripts1.userScripts.isEmpty)
        XCTAssertFalse(userScripts2.userScripts.isEmpty)
        XCTAssertTrue(userScripts1 !== userScripts2)
        XCTAssertTrue(userScripts2 === userScripts3)
        c.cancel()
    }

}
