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

struct AdjacentItemEnumerator {

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

    let itemIndex: Int

    init(itemIndex: Int) {
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
