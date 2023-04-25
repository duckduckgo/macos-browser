//
//  BurnerWindowPopover.swift
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

final class BurnerWindowPopover: NSPopover {

    override init() {
        super.init()

        self.behavior = .transient

        setupContentController()
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    // swiftlint:disable force_cast
    var viewController: BurnerWindowPopoverViewController { contentViewController as! BurnerWindowPopoverViewController }
    // swiftlint:enable force_cast

    weak var originatingWindow: NSWindow?

    private func setupContentController() {
        let storyboard = NSStoryboard(name: "BurnerWindowPopover", bundle: nil)
        let controller = storyboard.instantiateController(
            identifier: "BurnerWindowPopoverViewController") { coder -> BurnerWindowPopoverViewController? in
                return BurnerWindowPopoverViewController(coder: coder)
            }
        controller.delegate = self
        contentViewController = controller
    }

}

extension BurnerWindowPopover: BurnerWindowPopoverViewControllerDelegate {

    func burnerWindowPopoverViewControllerDidConfirm(_ burnerWindowPopoverViewController: BurnerWindowPopoverViewController) {
        originatingWindow?.performClose(self)
    }

}
