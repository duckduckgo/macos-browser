//
//  PopupBlockedPopover.swift
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

import Cocoa

final class PopupBlockedPopover: NSPopover {

    override init() {
        super.init()

        behavior = .applicationDefined
        setupContentController()
    }

    required init?(coder: NSCoder) {
        fatalError("PopupBlockedPopover: Bad initializer")
    }

    // swiftlint:disable force_cast
    private func setupContentController() {
        let storyboard = NSStoryboard(name: "PermissionAuthorization", bundle: nil)
        let controller = storyboard
            .instantiateController(withIdentifier: "PopupBlockedViewController") as! PopupBlockedViewController
        contentViewController = controller
    }
    // swiftlint:enable force_cast

}

final class PopupBlockedViewController: NSViewController {
    @IBOutlet weak var descriptionLabel: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        descriptionLabel.stringValue = UserText.permissionPopupBlockedPopover
    }

    override func viewDidAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.dismiss()
        }
    }

}
