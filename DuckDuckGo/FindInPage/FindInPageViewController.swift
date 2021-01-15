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
import Combine

#warning("BRINDY: need to handle escape being pressed")
#warning("BRINDY: fix address to handle responder and show caret")
class FindInPageViewController: NSViewController {

    var onClose: (() -> Void)?

    @Published var model: FindInPageModel? {
        didSet {
            print("***", #function, model?.id as Any)
        }
    }

    @IBOutlet weak var textField: NSTextField!
    @IBOutlet weak var focusRingView: FocusRingView!
    @IBOutlet weak var statusField: NSTextField!
    @IBOutlet weak var nextButton: NSButton!
    @IBOutlet weak var previousButton: NSButton!

    private var modelCancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        textField.delegate = self
        listenForTextFieldResponderNotifications()
        subscribeToModelChanges()
        updateFieldStates()
    }

    @IBAction func findInPageNext(_ sender: Any?) {
        print("***", #function)
        model?.next()
    }

    @IBAction func findInPagePrevious(_ sender: Any?) {
        print("***", #function)
        model?.previous()
    }

    @IBAction func findInPageDone(_ sender: Any?) {
        onClose?()
    }

    override func responds(to aSelector: Selector!) -> Bool {

        switch aSelector {
        case #selector(findInPageNext(_:)),
             #selector(findInPagePrevious(_:)):
            return model?.matchesFound ?? 0 > 0

        default:
            return super.responds(to: aSelector)
        }

    }

    func makeMeFirstResponder() {
        textField.makeMeFirstResponder()
    }

    private func subscribeToModelChanges() {
        modelCancellables.forEach { $0.cancel() }
        modelCancellables.removeAll()
        $model.receive(on: DispatchQueue.main).sink { [weak self] _ in
            print("***", #function, "received", self?.model as Any)

            self?.updateFieldStates()

            guard let self = self,
                  let model = self.model else { return }

            model.$text.receive(on: DispatchQueue.main).sink { [weak self] text in
                self?.textField.stringValue = text
            }.store(in: &self.modelCancellables)

            model.$matchesFound.receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.rebuildStatus()
                self?.updateFieldStates()
            }.store(in: &self.modelCancellables)

            model.$currentSelection.receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.rebuildStatus()
            }.store(in: &self.modelCancellables)

        }.store(in: &modelCancellables)
    }

    private func rebuildStatus() {
        guard let model = model else { return }
        #warning("BRINDY: needs localisation")
        statusField.stringValue = "\(model.currentSelection) of \(model.matchesFound)"
    }
    
    private func updateView(firstResponder: Bool) {
        print("***", #function)
        focusRingView.updateView(stroke: firstResponder)
    }

    private func updateFieldStates() {
        statusField.isHidden = model?.matchesFound ?? 0 == 0
        nextButton.isEnabled = model?.matchesFound ?? 0 > 0
        previousButton.isEnabled = model?.matchesFound ?? 0 > 0
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
