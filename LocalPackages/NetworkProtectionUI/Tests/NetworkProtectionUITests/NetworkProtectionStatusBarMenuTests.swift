//
//  NetworkProtectionStatusBarMenuTests.swift
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
import Combine
import SwiftUI
import NetworkProtection
import XCTest
@testable import NetworkProtectionUI

final class StatusBarMenuTests: XCTestCase {

    private final class TestAppLauncher: AppLaunching {
        func launchApp(withCommand command: NetworkProtection.AppLaunchCommand) async {
            // no-op
        }
    }

    private final class TestStatusReporter: NetworkProtectionStatusReporter {
        var statusPublisher = CurrentValueSubject<NetworkProtection.ConnectionStatus, Never>(.disconnected)
        var connectivityIssuesPublisher = CurrentValueSubject<Bool, Never>(false)
        var serverInfoPublisher = CurrentValueSubject<NetworkProtection.NetworkProtectionStatusServerInfo, Never>(.unknown)
        var connectionErrorPublisher = CurrentValueSubject<String?, Never>(nil)
        var controllerErrorMessagePublisher = CurrentValueSubject<String?, Never>(nil)

        func forceRefresh() {
            // no-op
        }
    }

    func testShowStatusBarMenu() {
        let item = NSStatusItem()
        let menu = StatusBarMenu(
            statusItem: item,
            statusReporter: TestStatusReporter(),
            appLauncher: TestAppLauncher(),
            iconProvider: MenuIconProvider())

        menu.show()

        XCTAssertTrue(item.isVisible)
    }

    func testHideStatusBarMenu() {
        let item = NSStatusItem()
        let menu = StatusBarMenu(
            statusItem: item,
            statusReporter: TestStatusReporter(),
            appLauncher: TestAppLauncher(),
            iconProvider: MenuIconProvider())

        menu.hide()

        XCTAssertFalse(item.isVisible)
    }
}
