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
import XCTest
import SwiftUI
@testable import DuckDuckGo_Privacy_Browser

class NetworkProtectionStatusBarMenuTests: XCTestCase {
    func testProperInitialization() {
        let item = NSStatusItem()
        _ = NetworkProtectionStatusBarMenu(statusItem: item)

        guard let nsMenu = item.menu else {
            XCTFail("Expected an NSMenu to exist")
            return
        }

        XCTAssertEqual(nsMenu.items.count, 1)

        guard let menuItem = nsMenu.items.first else {
            XCTFail("Expected an NSMenuItem to exist")
            return
        }

        guard let statusView = menuItem.view else {
            XCTFail("Expected the NSMenuItem's view to be set")
            return
        }

        XCTAssertEqual(statusView.className, NSHostingView<NetworkProtectionStatusView>.className())
    }

    func testShowStatusBarMenu() {
        let item = NSStatusItem()
        let menu = NetworkProtectionStatusBarMenu(statusItem: item)

        menu.show()

        XCTAssertTrue(item.isVisible)
    }

    func testHideStatusBarMenu() {
        let item = NSStatusItem()
        let menu = NetworkProtectionStatusBarMenu(statusItem: item)

        menu.hide()

        XCTAssertFalse(item.isVisible)
    }
}
