//
//  UndoFireproofingViewController.swift
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

class UndoFireproofingViewController: NSViewController {

    enum Constants {
        static let storyboardName = "Fireproofing"
        static let identifier = "UndoFireproofingViewController"
        static let autoDismissDuration: TimeInterval = 1.75
    }

    static func create(for domain: String) -> UndoFireproofingViewController {
        let storyboard = NSStoryboard(name: Constants.storyboardName, bundle: nil)

        return storyboard.instantiateController(identifier: Constants.identifier) { coder in
            return UndoFireproofingViewController(coder: coder, domain: domain)
        }
    }

    @IBOutlet weak var titleLabel: NSTextField!

    private var timer: Timer?
    private var domain: String

    init?(coder: NSCoder, domain: String) {
        self.domain = domain
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("You must create this view controller with a domain.")
    }

    deinit {
        cancelAutoDismissTimer()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.titleLabel.stringValue = UserText.domainIsFireproof(domain: domain)

        if let mouseOverView = self.view as? MouseOverView {
            mouseOverView.delegate = self
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        scheduleAutoDismissTimer()
    }

    private func cancelAutoDismissTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleAutoDismissTimer() {
        cancelAutoDismissTimer()
        timer = Timer.scheduledTimer(withTimeInterval: Constants.autoDismissDuration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.presentingViewController?.dismiss(self)
        }
    }

}

extension UndoFireproofingViewController: MouseOverViewDelegate {

    func mouseOverView(_ mouseOverView: MouseOverView, isMouseOver: Bool) {
        if isMouseOver {
            cancelAutoDismissTimer()
        } else {
            scheduleAutoDismissTimer()
        }
    }

}
