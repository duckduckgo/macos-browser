//
//  ArrayExtensionTests.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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

final class ArrayExtensionTests: XCTestCase {

    // MARK: - chunk

    func testThatChunkOfEmptyArrayReturnsEmptyArray() {
        XCTAssertEqual([Int]().chunk(with: 1, offset: 0), [])
    }

    func testThatChunkWithZeroLengthReturnsEmptyArray() {
        XCTAssertEqual([1, 2, 3].chunk(with: 0, offset: 0), [])
    }

    func testThatChunkWithOffsetOutsideOfBoundsReturnsEmptyArray() {
        XCTAssertEqual([1, 2, 3].chunk(with: 1, offset: 100), [])
    }

    func testThatChunkWithNegativeOffsetReturnsEmptyArray() {
        XCTAssertEqual([1, 2, 3].chunk(with: 1, offset: -5), [])
    }

    func testThatChunkWithNegativeLimitReturnsEmptyArray() {
        XCTAssertEqual([1, 2, 3].chunk(with: -1, offset: 0), [])
    }

    func testThatChunkReturnsPartOfAnArray() {
        let array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        XCTAssertEqual(array.chunk(with: 0, offset: 0), [])
        XCTAssertEqual(array.chunk(with: 5, offset: 0), [1, 2, 3, 4, 5])
        XCTAssertEqual(array.chunk(with: 5, offset: 1), [2, 3, 4, 5, 6])
        XCTAssertEqual(array.chunk(with: 3, offset: 6), [7, 8, 9])
    }

    func testThatChunkEndingOutsideOfArrayBoundsIsCappedAtArrayEnd() {
        XCTAssertEqual([1, 2, 3].chunk(with: 100, offset: 2), [3])
        XCTAssertEqual([1, 2, 3, 4, 5, 6].chunk(with: 4, offset: 4), [5, 6])
    }
}
