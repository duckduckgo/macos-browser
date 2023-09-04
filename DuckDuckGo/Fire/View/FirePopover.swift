//
//  FirePopover.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

final class FirePopover: NSPopover {

    override var mainWindowMargin: CGFloat { -14 }

    private static let minScreenEdgeMargin = 10.0
    private static let defaultScreenEdgeCorrection = 12.0

    // always position the Fire popover by the right edge
    override func adjustFrame(_ frame: NSRect) -> NSRect {
        let boundingFrame = self.boundingFrame
        guard !boundingFrame.isInfinite else { return frame }
        guard let popoverWindow = self.contentViewController?.view.window else {
            assertionFailure("no popover window")
            return frame
        }

        var frame = frame
        frame.origin.x = boundingFrame.maxX - popoverWindow.frame.width
        if let mainWindow = popoverWindow.parent,
           let screen = mainWindow.screen,
           mainWindow.frame.maxX > screen.visibleFrame.maxX - Self.defaultScreenEdgeCorrection {
            // close to the screen edge the Popover gets shifted to the left
            frame.origin.x += Self.defaultScreenEdgeCorrection - (screen.visibleFrame.maxX - mainWindow.frame.maxX)
        }
        return frame
    }

    init(fireViewModel: FireViewModel, tabCollectionViewModel: TabCollectionViewModel) {
        super.init()

        self.animates = false
        self.behavior = .semitransient

        setupContentController(fireViewModel: fireViewModel, tabCollectionViewModel: tabCollectionViewModel)
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    // swiftlint:disable force_cast
    var viewController: FirePopoverWrapperViewController { contentViewController as! FirePopoverWrapperViewController }
    // swiftlint:enable force_cast

    private func setupContentController(fireViewModel: FireViewModel, tabCollectionViewModel: TabCollectionViewModel) {
        let storyboard = NSStoryboard(name: "Fire", bundle: nil)
        let controller = storyboard.instantiateController(identifier: "FirePopoverWrapperViewController") { coder -> FirePopoverWrapperViewController? in
            return FirePopoverWrapperViewController(coder: coder, fireViewModel: fireViewModel, tabCollectionViewModel: tabCollectionViewModel)
        }
        contentViewController = controller
    }

}
