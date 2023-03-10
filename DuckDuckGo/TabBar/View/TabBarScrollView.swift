//
//  TabBarScrollView.swift
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

final class TabBarScrollView: NSScrollView {

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    // Hiding scrollers in storyboard doesn't work. It's a known bug

    override var hasHorizontalScroller: Bool {
        get { return false }
        set { super.hasHorizontalScroller = newValue }
    }

    override var horizontalScroller: NSScroller? {
        get { return nil }
        set { super.horizontalScroller = newValue }
    }

}

extension TabBarScrollView {

    func updateScrollElasticity(with tabMode: TabBarViewController.TabMode) {
        horizontalScrollElasticity = tabMode == .divided ? .none : .allowed
    }

}
