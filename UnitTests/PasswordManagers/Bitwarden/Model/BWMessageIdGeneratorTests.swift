//
//  BWMessageIdGeneratorTests.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
@testable import DuckDuckGo_Privacy_Browser

final class BWMessageGeneratorTests: XCTestCase {

    func testWhenGeneratorReturnsMessageId_ThenItIsStoredInItsCache() {
        let messageIdGenerator = BWMessageIdGenerator()
        let messageId = messageIdGenerator.generateMessageId()
        XCTAssert(messageIdGenerator.cache.contains(messageId))
    }

    func testWhenGeneratorVerifiesMessageId_ThenItIsRemovedFromCache() {
        let messageIdGenerator = BWMessageIdGenerator()
        let messageId = messageIdGenerator.generateMessageId()

        let verificationResult = messageIdGenerator.verify(messageId: messageId)
        XCTAssert(verificationResult)

        XCTAssert(messageIdGenerator.cache.isEmpty)
    }

    func testWhenGeneratorCantRecognizeMessageIt_ThenItReturnsFalse() {
        let messageIdGenerator = BWMessageIdGenerator()

        let verificationResult = messageIdGenerator.verify(messageId: "random message if")
        XCTAssertFalse(verificationResult)
    }

}
