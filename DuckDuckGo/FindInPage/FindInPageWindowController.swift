//
//  TooltipWindowController.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import os.log

class FindInPageWindowController: NSWindowController {

    func show(parentWindow: NSWindow, topLeft: NSPoint) {
        guard parentWindow.childWindows != nil, let window = self.window else {
            os_log("FindInPageWindowController: Showing find in page window failed", type: .error)
            return
        }
        parentWindow.addChildWindow(window, ordered: .above)
//        window.setFrame(NSRect(x: 0, y: 0, width: 400, height: 40), display: true)
        window.setFrameTopLeftPoint(topLeft)
    }

}
