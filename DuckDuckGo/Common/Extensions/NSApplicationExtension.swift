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

    @objc enum RunType: Int, CustomStringConvertible {
        case normal
        case unitTests
        case integrationTests
        case uiTests

        var description: String {
            switch self {
            case .normal: return "normal"
            case .unitTests: return "unitTests"
            case .integrationTests: return "integrationTests"
            case .uiTests: return "uiTests"
            }
        }
    }
    @objc dynamic var runType: RunType { .normal }

    var isRunningUnitTests: Bool {
        if case .unitTests = runType { return true }
        return false
    }

    var isRunningIntegrationTests: Bool {
        if case .integrationTests = runType { return true }
        return false
    }

    var mainMenuTyped: MainMenu {
        return mainMenu as! MainMenu // swiftlint:disable:this force_cast
    }

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
