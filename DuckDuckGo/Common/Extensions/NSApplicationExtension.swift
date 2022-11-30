//
//  NSApplicationExtension.swift
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
import Combine

extension NSApplication {

    var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    // swiftlint:disable force_cast
    var mainMenuTyped: MainMenu {
        return mainMenu as! MainMenu
    }
    // swiftlint:enable force_cast

    var isCommandPressed: Bool {
        currentEvent?.modifierFlags.contains(.command) ?? false
    }

    var isShiftPressed: Bool {
        currentEvent?.modifierFlags.contains(.shift) ?? false
    }

    var isOptionPressed: Bool {
        currentEvent?.modifierFlags.contains(.option) ?? false
    }

    var isReturnOrEnterPressed: Bool {
        guard let event = currentEvent,
              case .keyDown = event.type
        else { return false }
        return event.keyCode == 36 || event.keyCode == 76
    }

    func isActivePublisher() -> AnyPublisher<Bool, Never> {
        let activated = NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification).map { _ in true }
        let deactivated = NotificationCenter.default
            .publisher(for: NSApplication.didResignActiveNotification).map { _ in false }

        return Just(self.isActive)
            .merge(with: activated.merge(with: deactivated))
            .eraseToAnyPublisher()
    }

}
