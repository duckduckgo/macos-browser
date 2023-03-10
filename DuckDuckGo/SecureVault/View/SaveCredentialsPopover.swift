//
//  SaveCredentialsPopover.swift
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
import BrowserServicesKit

final class SaveCredentialsPopover: NSPopover {

    override init() {
        super.init()

        self.animates = false
        self.behavior = .applicationDefined

        setupContentController()
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    // swiftlint:disable:next force_cast
    var viewController: SaveCredentialsViewController { contentViewController as! SaveCredentialsViewController }

    private func setupContentController() {
        let controller = SaveCredentialsViewController.create()
        controller.delegate = self
        contentViewController = controller
    }

}

extension SaveCredentialsPopover: SaveCredentialsDelegate {

    func shouldCloseSaveCredentialsViewController(_: SaveCredentialsViewController) {
        DispatchQueue.main.async {
            self.close()
        }
    }

}
