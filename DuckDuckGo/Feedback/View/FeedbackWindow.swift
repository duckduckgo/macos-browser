//
//  FeedbackWindow.swift
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

// Based on Thomasses answer - Do screenshot checkbox
// Do all kinds of feedback screens
// Open design review with the build
// Moving of window with the bar

import Cocoa

final class FeedbackWindow: NSWindow {

    enum Size {
        static let width: CGFloat = 360
        static let height: CGFloat = 320
    }

    override var canBecomeMain: Bool { false }

    var feedbackViewController: FeedbackViewController {
        // swiftlint:disable:next force_cast
        contentViewController as! FeedbackViewController
    }
}
