//
//  NSRectExtension.swift
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

extension NSRect {

    var topLeft: NSPoint {
        NSPoint(x: minX, y: maxY)
    }

    var center: NSPoint {
        NSPoint(x: midX, y: midY)
    }

    var droppingPoint: NSPoint {
        NSPoint(x: self.midX, y: maxY)
    }

    func frameOrigin(fromDroppingPoint droppingPoint: NSPoint) -> NSPoint {
        NSPoint(x: droppingPoint.x - self.width / 2, y: droppingPoint.y - self.height)
    }

    // Apply an offset so that we don't get caught by the "Line of Death" https://textslashplain.com/2017/01/14/the-line-of-death/
    func insetFromLineOfDeath(flipped: Bool) -> NSRect {
        let offset = 3.0
        assert(height > offset * 2)
        return insetBy(dx: 0, dy: offset)
    }

}
