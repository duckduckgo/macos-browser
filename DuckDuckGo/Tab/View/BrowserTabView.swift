//
//  BrowserTabView.swift
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

import AppKit
import SwiftUI

private protocol HostingViewProtocol {}
extension NSHostingView: HostingViewProtocol {}

private extension NSView {
    var isHostingView: Bool {
        return self is HostingViewProtocol
    }
}

final class BrowserTabView: ColorView {

    // Returns correct subview for the rendering of snapshots
    func findContentSubview(containsHostingView: Bool) -> NSView? {
        guard let content = subviews.last else { return nil }

        if containsHostingView && !content.isHostingView,
           let subview = content.subviews.first {
            assert(subview.isHostingView)
            return subview
        }

        return content
    }

    // MARK: NSDraggingDestination

    override func draggingEntered(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        return (nextResponder as? NSDraggingDestination)?.draggingEntered?(draggingInfo) ?? .none
    }

    override func draggingUpdated(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        return (nextResponder as? NSDraggingDestination)?.draggingUpdated?(draggingInfo) ?? .none
    }

    override func performDragOperation(_ draggingInfo: NSDraggingInfo) -> Bool {
        return (nextResponder as? NSDraggingDestination)?.performDragOperation?(draggingInfo) ?? false
    }

}
