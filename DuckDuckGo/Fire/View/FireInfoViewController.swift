//
//  FireInfoViewController.swift
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

protocol FireInfoViewControllerDelegate: AnyObject {

    func fireInfoViewControllerDidConfirm(_ fireInfoViewController: FireInfoViewController)

}

final class FireInfoViewController: NSViewController {

    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet weak var gotItButton: NSButton!

    weak var delegate: FireInfoViewControllerDelegate?

    override func viewDidLoad() {
        titleLabel.stringValue = UserText.fireInfoDialogTitle
        descriptionLabel.stringValue = UserText.fireInfoDialogDescription
        gotItButton.title = UserText.gotIt
    }

    override func mouseDown(with event: NSEvent) {}

    @IBAction func gotItAction(_ sender: Any) {
        delegate?.fireInfoViewControllerDidConfirm(self)
    }

}
