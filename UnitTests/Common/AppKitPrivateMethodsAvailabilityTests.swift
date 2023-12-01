//
//  AppKitPrivateMethodsAvailabilityTests.swift
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

import XCTest
import AppKit
@testable import DuckDuckGo_Privacy_Browser

final class AppKitPrivateMethodsAvailabilityTests: XCTestCase {

    func testLastLeftHit() {
        var window: NSWindow!
        autoreleasepool {
            window = NSWindow()
            window.isReleasedWhenClosed = false

            let didAppearExpectation = expectation(description: "view did appear")
            let view = TestHitView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
            let viewController = TestHitViewController(didAppearExpectation: didAppearExpectation, view: view)
            window.contentViewController = viewController

            window.setFrame(NSRect(x: 0, y: 0, width: 100, height: 123), display: false)
            NSApp.activate(ignoringOtherApps: true)

            window.makeKeyAndOrderFront(nil)
            waitForExpectations(timeout: 1.0)

            view.mouseDownExpectation = expectation(description: "mouseDown received")

            let event = NSEvent.mouseEvent(with: .leftMouseDown,
                                           location: view.convert(NSPoint(x: 50, y: 50), to: nil),
                                           modifierFlags: [],
                                           timestamp: CACurrentMediaTime(),
                                           windowNumber: window.windowNumber,
                                           context: nil,
                                           eventNumber: -22966,
                                           clickCount: 1,
                                           pressure: 1)!
            window.postEvent(event, atStart: false)

            waitForExpectations(timeout: 0.1)

            // window should have lastLeftHit set to the clicked view after a click event
            XCTAssertEqual(window.lastLeftHit, view)
            window.evilHackToClearLastLeftHitInWindow()
            XCTAssertEqual(window.lastLeftHit, nil)

            window.close()
            window = nil
        }
    }

}

private class TestHitViewController: NSViewController {
    let didAppearExpectation: XCTestExpectation
    init(didAppearExpectation: XCTestExpectation, view: NSView) {
        self.didAppearExpectation = didAppearExpectation

        super.init(nibName: nil, bundle: nil)
        self.view = view
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func viewDidAppear() {
        DispatchQueue.main.async {
            self.didAppearExpectation.fulfill()
        }
    }
}

private class TestHitView: NSView {
    var mouseDownExpectation: XCTestExpectation!
    override func mouseDown(with event: NSEvent) {
        mouseDownExpectation.fulfill()
        super.mouseDown(with: event)
    }
}
