//
//  LoadTargetModifiers.swift
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

import AppKit

enum LoadTargetModifiers {
    case retarget(NewWindowKind)
    case download

    init?(_ event: NSEvent) {
        switch event.modifierFlags.intersection([.command, .shift, .option, .control]) {
        case .command:
            self = .retarget(.tab(selected: false))
        case [.command, .shift]:
            self = .retarget(.tab(selected: true))
        case [.command, .option]:
            self = .retarget(.window(active: false))
        case [.command, .shift, .option]:
            self = .retarget(.window(active: true))
        case .option, [.option, .shift]:
            self = .download
        default:
            return nil
        }
    }

    static func current() -> Self? {
        NSApp.currentEvent.flatMap(LoadTargetModifiers.init)
    }
}
