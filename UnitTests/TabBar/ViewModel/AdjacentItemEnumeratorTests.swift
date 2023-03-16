//
//  AdjacentItemEnumeratorTests.swift
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

import XCTest
@testable import DuckDuckGo_Privacy_Browser

class AdjacentItemEnumeratorTests: XCTestCase {

    func testAdjacentItems() throws {
        var enumerator = AdjacentItemEnumerator(itemIndex: 5)

        var indices: [Int?] = []
        for _ in 0..<10 {
            indices.append(enumerator.nextIndex(arraySize: 20))
        }

        XCTAssertEqual(indices.compactMap({ $0 }), [6, 4, 7, 3, 8, 2, 9, 1, 10, 0])
    }

    func testThatEnumeratorDoesNotCrossZero() throws {
        var enumerator = AdjacentItemEnumerator(itemIndex: 0)

        var indices: [Int?] = []
        for _ in 0..<5 {
            indices.append(enumerator.nextIndex(arraySize: 10))
        }

        XCTAssertEqual(indices.compactMap({ $0 }), [1, 2, 3, 4, 5])
    }

    func testThatEnumeratorDoesNotExceedArraySize() throws {
        var enumerator = AdjacentItemEnumerator(itemIndex: 8)

        var indices: [Int?] = []
        for _ in 0..<5 {
            indices.append(enumerator.nextIndex(arraySize: 10))
        }

        XCTAssertEqual(indices.compactMap({ $0 }), [9, 7, 6, 5, 4])
    }

    func testThatEnumeratorReturnsNilWhenOutOfArrayBounds() throws {
        var enumerator = AdjacentItemEnumerator(itemIndex: 2)

        var indices: [Int?] = []
        for _ in 0..<5 {
            indices.append(enumerator.nextIndex(arraySize: 4))
        }

        XCTAssertEqual(indices.compactMap({ $0 }), [3, 1, 0])
    }
}
