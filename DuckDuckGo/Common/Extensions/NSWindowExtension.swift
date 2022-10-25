//
//  NSWindowExtension.swift
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

import Cocoa

extension NSWindow {

    func setFrameOrigin(droppingPoint: NSPoint) {
        let frameOrigin = NSPoint(x: droppingPoint.x - frame.size.width/2, y: droppingPoint.y - frame.size.height)
        setFrameOrigin(frameOrigin)
    }

    func evilHackToClearLastLeftHitInWindow() {
        guard self.responds(to: #selector(NSWindow._evilHackToClearlastLeftHitInWindow)) else {
            assertionFailure("_evilHackToClearlastLeftHitInWindow is gone")
            return
        }
        self._evilHackToClearlastLeftHitInWindow()
    }

}
