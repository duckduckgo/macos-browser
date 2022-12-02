//
//  NSEventExtension.swift
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

extension NSEvent {

    var isContextClick: Bool {
        let isControlClick = self.type == .leftMouseDown && (self.modifierFlags.rawValue & NSEvent.ModifierFlags.control.rawValue != 0)
        let isRightClick = self.type == .rightMouseDown
        return isControlClick || isRightClick
    }

    var isReturnOrEnterPressed: Bool {
        guard self.type == .keyDown else { return false }
        return [36, 76].contains(self.keyCode)
    }

}
