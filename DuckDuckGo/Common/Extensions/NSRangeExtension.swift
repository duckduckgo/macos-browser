//
//  NSRangeExtension.swift
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

import Foundation

extension NSRange {

    /**
     Returns a range adjusted to fall within a given boundingRange range.

     If the `range` range is completely outside the `boundingRange` range, it will result in an empty range at the start or end of the `boundingRange` range.
     If the `range` range is only partially outside the `boundingRange` range, it will be adjusted to the start or end of the `selectable` range.
     */
    func adjusted(to boundingRange: NSRange) -> NSRange {
        if let intersection = intersection(boundingRange) {
            return intersection
        }

        if location < boundingRange.location {
            return NSRange(location: boundingRange.location, length: 0)
        } else {
            return NSRange(location: boundingRange.upperBound, length: 0)
        }
    }

}
