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

    init(fireViewModel: FireViewModel, tabCollectionViewModel: TabCollectionViewModel) {
        super.init()

        self.behavior = .transient

        setupContentController(fireViewModel: fireViewModel, tabCollectionViewModel: tabCollectionViewModel)
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    // swiftlint:disable force_cast
    var viewController: FirePopoverViewController { contentViewController as! FirePopoverViewController }
    // swiftlint:enable force_cast

    private func setupContentController(fireViewModel: FireViewModel, tabCollectionViewModel: TabCollectionViewModel) {
        let storyboard = NSStoryboard(name: "Fire", bundle: nil)
        let controller = storyboard.instantiateController(identifier: "FirePopoverViewController") { coder -> FirePopoverViewController? in
            return FirePopoverViewController(coder: coder, fireViewModel: fireViewModel, tabCollectionViewModel: tabCollectionViewModel)
        }
        contentViewController = controller
    }

}
