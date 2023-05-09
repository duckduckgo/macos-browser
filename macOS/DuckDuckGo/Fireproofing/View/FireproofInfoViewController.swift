//
//  FireproofInfoViewController.swift
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

final class FireproofInfoViewController: NSViewController {

    enum Constants {
        static let storyboardName = "Fireproofing"
        static let identifier = "FireproofInfoViewController"
    }

    static func create(for domain: String) -> FireproofInfoViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)

        return storyboard.instantiateController(identifier: Constants.identifier) { coder in
            return FireproofInfoViewController(coder: coder, domain: domain.droppingWwwPrefix())
        }
    }

    @IBOutlet weak var doneButton: NSButton! {
        didSet {
            doneButton.bezelStyle = .rounded
        }
    }
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var separator: NSView! {
        didSet {
            separator.wantsLayer = true
            separator.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.1).cgColor
        }
    }

    private var domain: String

    init?(coder: NSCoder, domain: String) {
        self.domain = domain
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("You must create this view controller with a domain.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.titleLabel.stringValue = UserText.domainIsFireproof(domain: domain)
    }

    @IBAction func removeFireproofing(_ sender: AnyObject) {
        FireproofDomains.shared.remove(domain: domain)
        presentingViewController?.dismiss(self)
    }

    @IBAction func dismiss(_ sender: AnyObject) {
        presentingViewController?.dismiss(self)
    }

}
