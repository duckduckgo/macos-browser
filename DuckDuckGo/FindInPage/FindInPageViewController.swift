//
//  FindInPageViewController.swift
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

class FindInPageViewController: NSViewController {

    var onClose: (() -> Void)?

    var model: FindInPageModel? {
        didSet {
            print("***", #function, model?.id as Any)
        }
    }

    @IBOutlet weak var textField: NSTextField!
    @IBOutlet weak var addressBarView: AddressBarView!

    override func viewDidLoad() {
        super.viewDidLoad()
        textField.delegate = self
        listenForTextFieldResponderNotifications()
    }

    @IBAction func findInPageNext(_ sender: Any?) {
        print("***", #function)
    }

    @IBAction func findInPagePrevious(_ sender: Any?) {
        print("***", #function)
    }

    @IBAction func findInPageDone(_ sender: Any?) {
        onClose?()
    }

    @IBAction func findInPage(_ sender: Any?) {
        textField.makeMeFirstResponder()
    }

    func makeMeFirstResponder() {
        textField.makeMeFirstResponder()
    }

    private func updateView(firstResponder: Bool) {
        print("***", #function)
        addressBarView.updateView(stroke: firstResponder)
    }

    private func listenForTextFieldResponderNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(textFieldFirstReponderNotification(_:)),
                                               name: .firstResponder,
                                               object: nil)
    }

}

extension FindInPageViewController {

    @objc func textFieldFirstReponderNotification(_ notification: Notification) {
        print("***", #function)
        // NSTextField passes its first responder status down to a child view of NSTextView class
        if let textView = notification.object as? NSTextView, textView.superview?.superview === textField {
            updateView(firstResponder: true)
        } else {
            updateView(firstResponder: false)
        }
    }

}

extension FindInPageViewController: NSTextFieldDelegate {
    
    func controlTextDidEndEditing(_ obj: Notification) {
        print("***", #function)

    }

    func controlTextDidChange(_ obj: Notification) {
        print("***", #function)
    }

}
