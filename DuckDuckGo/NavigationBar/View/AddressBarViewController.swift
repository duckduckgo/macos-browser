//
//  AddressBarViewController.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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
import os.log
import Combine

class AddressBarViewController: NSViewController {

    @IBOutlet weak var textField: AddressBarTextField!
    @IBOutlet weak var passiveTextField: NSTextField!
    @IBOutlet weak var reloadButton: NSButton!

    private var tabCollectionViewModel: TabCollectionViewModel

    private var selectedTabViewModelCancelable: AnyCancellable?
    private var reloadButtonCancelable: AnyCancellable?
    private var passiveAddressBarStringCancelable: AnyCancellable?

    required init?(coder: NSCoder) {
        fatalError("AddressBarViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setView(firstResponder: false, animated: false)
        textField.tabCollectionViewModel = tabCollectionViewModel
        bindSelectedTabViewModel()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(textFieldFirstReponderNotification(_:)),
                                               name: .firstResponder,
                                               object: nil)
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        textField.viewDidLayout()
    }

    @IBAction func reloadAction(_ sender: NSButton) {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }

        selectedTabViewModel.tab.reload()
    }

    private var addressBarView: AddressBarView? {
        return view as? AddressBarView
    }

    private func bindSelectedTabViewModel() {
        selectedTabViewModelCancelable = tabCollectionViewModel.$selectedTabViewModel.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.setView(firstResponder: false, animated: false)
            self?.bindReloadButton()
            self?.bindPassiveAddressBarString()
        }
    }

    private func bindReloadButton() {
        reloadButtonCancelable?.cancel()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            reloadButton.isEnabled = false
            return
        }

        reloadButtonCancelable = selectedTabViewModel.$canReload.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.setReloadButton()
        }
    }

    private func bindPassiveAddressBarString() {
        passiveAddressBarStringCancelable?.cancel()

        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            textField.stringValue = ""
            return
        }
        passiveAddressBarStringCancelable = selectedTabViewModel.$passiveAddressBarString.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.setPassiveTextField()
        }
    }

    private func setReloadButton() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }

        reloadButton.isEnabled = selectedTabViewModel.canReload
    }

    private func setPassiveTextField() {
        guard let selectedTabViewModel = tabCollectionViewModel.selectedTabViewModel else {
            os_log("%s: Selected tab view model is nil", log: OSLog.Category.general, type: .error, className)
            return
        }

        passiveTextField.stringValue = selectedTabViewModel.passiveAddressBarString
    }

    private func setView(firstResponder: Bool, animated: Bool) {
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 1/3
                self.textField.animator().alphaValue = firstResponder ? 1 : 0
                self.passiveTextField.animator().alphaValue = firstResponder ? 0 : 1
            }
        } else {
            self.textField.alphaValue = firstResponder ? 1 : 0
            self.passiveTextField.alphaValue = firstResponder ? 0 : 1
        }

        self.addressBarView?.setView(firstResponder: firstResponder, animated: animated)
    }
    
}

extension AddressBarViewController {

    @objc func textFieldFirstReponderNotification(_ notification: Notification) {
        // NSTextField passes its first responder status down to a child view of NSTextView class
        if let textView = notification.object as? NSTextView, textView.superview?.superview === textField {
            setView(firstResponder: true, animated: true)
        } else {
            if notification.object as? WebView != nil {
                setView(firstResponder: false, animated: true)
            } else {
                setView(firstResponder: false, animated: false)
            }
        }
    }
    
}
