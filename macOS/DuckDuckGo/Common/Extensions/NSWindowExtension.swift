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

    private static let lastLeftHitKey = "_lastLeftHit"
    var lastLeftHit: NSView? {
        return try? NSException.catch {
            self.value(forKey: Self.lastLeftHitKey) as? NSView
        }
    }

    func evilHackToClearLastLeftHitInWindow() {
        guard let oldValue = self.lastLeftHit else { return }
        let oldValueRetainCount = CFGetRetainCount(oldValue)
        defer {
            // compensate unbalanced release call
            if CFGetRetainCount(oldValue) < oldValueRetainCount {
                _=Unmanaged.passUnretained(oldValue).retain()
            }
        }
        NSException.try {
            autoreleasepool {
                self.setValue(nil, forKey: Self.lastLeftHitKey)
            }
        }
    }

}
