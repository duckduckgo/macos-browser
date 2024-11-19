//
//  ViewHighlighterTests.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
@testable import DuckDuckGo_Privacy_Browser

final class ViewHighlighterTests: XCTestCase {

    func testWhenHighlightViewIsCalledThenViewShouldContainAnimationView() {
        // GIVEN
        let (parent, child) = makeDummyViews()

        // WHEN
        ViewHighlighter.highlight(view: child, inParent: parent)

        // THEN
        XCTAssertNotNil(findFirstAnimationView(in: parent))
    }

    func testWhenIsViewIsHighligthedIsCalledAndViewIsHighlightedThenReturnTrue() {
        // GIVEN
        let (parent, child) = makeDummyViews()
        XCTAssertFalse(ViewHighlighter.isViewHighlighted(child))
        ViewHighlighter.highlight(view: child, inParent: parent)

        // WHEN
        let result = ViewHighlighter.isViewHighlighted(child)

        // THEN
        XCTAssertTrue(result)
    }

    func testWhenIsViewHighligthedIsCalledAndViewIsNotHighlightedThenReturnFalse() {
        // GIVEN
        let (_, child) = makeDummyViews()
        XCTAssertFalse(ViewHighlighter.isViewHighlighted(child))

        // WHEN
        let result = ViewHighlighter.isViewHighlighted(child)

        // THEN
        XCTAssertFalse(result)
    }

    func testWhenStopHighlightingViewIsCalledThenAnimationViewIsRemoved() {
        // GIVEN
        let (parent, child) = makeDummyViews()
        ViewHighlighter.highlight(view: child, inParent: parent)
        XCTAssertNotNil(findAllAnimationView(in: parent))

        // WHEN
        ViewHighlighter.stopHighlighting(view: child)

        // THEN
        XCTAssertNil(findFirstAnimationView(in: parent))
    }

    func testWhenViewIsHighlightedAndHighlightViewIsCalledThenNothingHappens() {
        // GIVEN
        let (parent, child) = makeDummyViews()
        ViewHighlighter.highlight(view: child, inParent: parent)
        XCTAssertEqual(findAllAnimationView(in: parent).count, 1)

        // WHEN
        ViewHighlighter.highlight(view: child, inParent: parent)

        // THEN
        XCTAssertEqual(findAllAnimationView(in: parent).count, 1)
    }

}

private extension ViewHighlighterTests {

    func makeDummyViews() -> (parent: NSView, child: NSView) {
        let parent = NSView()
        let child = NSView()
        parent.addSubview(child)
        return (parent, child)
    }

    func findAllAnimationView(in view: NSView) -> [NSView] {
        view.subviews.filter { $0.identifier == NSUserInterfaceItemIdentifier("lottie_pulse_animation_view") }
    }

    func findFirstAnimationView(in view: NSView) -> NSView? {
        findAllAnimationView(in: view).first
    }

}
