//
//  AdjacentItemEnumerator.swift
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

/**
 * This struct generates array indices adjacent to a given index.
 *
 * The _adjacent_ indices are generated as diffs against given index
 * with the following pattern:
 *
 *     1, -1, 2, -2, 3, -3, 4, -4, ...
 *
 */
struct AdjacentItemEnumerator {

    /**
     * The index of an item for which adjacent items indices are computed.
     */
    var itemIndex: Int

    /**
     * Last valid adjacent item index returned by `nextIndex(arraySize:)`.
     */
    var currentAdjacentIndex: Int {
        itemIndex + currentDiff
    }

    /**
     * Computes next adjacent index, constrained by `arraySize`.
     *
     * Returns the next available and valid index, between by `0` and `arraySize-1`,
     * or `nil` if the index falls outside array bounds.
     */
    mutating func nextIndex(arraySize: Int) -> Int? {
        if currentDiff != 0 {
            operation = operation.next
        }

        previousDiff = currentDiff
        currentDiff = operation.perform(with: currentDiff)

        let newIndex = itemIndex + currentDiff

        if newIndex < 0 || newIndex >= arraySize {
            let previousIndex = itemIndex + previousDiff
            if previousIndex <= 0 || previousIndex >= arraySize - 1 {
                return nil
            }
            return nextIndex(arraySize: arraySize)
        }
        return newIndex
    }

    /**
     * Resets the enumerator internal state
     *
     * Calling this function is equivalent to reinstantiating the enumerator.
     */
    mutating func reset() {
        currentDiff = 0
        previousDiff = 0
        operation = .toggleSignAndAdvance
    }

    init(itemIndex: Int = 0) {
        self.itemIndex = itemIndex
    }

    // MARK: - Private

    private var currentDiff = 0
    private var previousDiff = 0
    private var operation: Operation = .toggleSignAndAdvance

    private enum Operation {
        case toggleSign, toggleSignAndAdvance

        func perform(with value: Int) -> Int {
            switch self {
            case .toggleSign:
                return value * -1
            case .toggleSignAndAdvance:
                return (value * -1) + 1
            }
        }

        var next: Operation {
            switch self {
            case .toggleSign:
                return .toggleSignAndAdvance
            case .toggleSignAndAdvance:
                return .toggleSign
            }
        }
    }
}
