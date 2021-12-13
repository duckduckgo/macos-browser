//
//  WaitlistLockScreenViewController.swift
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
import Combine

final class WaitlistLockScreenViewController: NSViewController {
    
    // swiftlint:disable force_cast
    static func instantiate() -> NSViewController {
        let storyboard = NSStoryboard(name: "Waitlist", bundle: Bundle.main)
        return storyboard.instantiateController(withIdentifier: "WaitlistLockScreenViewController") as! NSViewController
    }
    // swiftlint:enable force_cast
    
    @IBOutlet var inviteCodeStateGroup: NSView!
    @IBOutlet var successStateGroup: NSView!
    
    @IBOutlet var inviteCodeTextField: NSTextField!
    @IBOutlet var quitButton: NSButton!
    @IBOutlet var continueButton: NSButton!
    
    @IBOutlet var networkRequestSpinner: NSProgressIndicator!
    @IBOutlet var errorLabel: NSTextField!
    
    private let viewModel = MacWaitlistLockScreenViewModel()
    private var viewStateCancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // The unlock screen always uses a light mode appearance, so it's hardcoded here to avoid fighting against
        // system controls that try to display in dark mode.
        view.appearance = NSAppearance(named: .aqua)
        
        viewStateCancellable = viewModel.$state.sink { [weak self] newState in
            self?.render(state: newState)
        }
        
        renderCurrentState()
    }
    
    @IBAction func quit(_ sender: NSButton) {
        // NSRunningApplication.current.terminate()
        exit(0)
    }
    
    @IBAction func continueButtonClicked(_ sender: NSButton) {
        if viewModel.state == .unlockSuccess {
            self.dismiss()
        } else {
            viewModel.attemptUnlock(code: inviteCodeTextField.stringValue)
        }
    }
    
    private func renderCurrentState() {
        render(state: viewModel.state)
    }

    private func render(state: MacWaitlistLockScreenViewModel.ViewState) {
        switch state {
        case .requiresUnlock:
            inviteCodeStateGroup.isHidden = false
            successStateGroup.isHidden = true
            
            continueButton.isEnabled = false
            errorLabel.isHidden = true
            networkRequestSpinner.isHidden = true
        case .unlockRequestInFlight:
            inviteCodeStateGroup.isHidden = false
            successStateGroup.isHidden = true

            continueButton.isEnabled = false
            errorLabel.isHidden = true
            networkRequestSpinner.startAnimation(nil)
            networkRequestSpinner.isHidden = false
        case .unlockSuccess:
            inviteCodeStateGroup.isHidden = true
            successStateGroup.isHidden = false
            
            networkRequestSpinner.isHidden = true
            errorLabel.isHidden = true
            
            quitButton.isHidden = true
            continueButton.isEnabled = true
            continueButton.title = "Get Started"
        case .unlockFailure:
            inviteCodeStateGroup.isHidden = false
            successStateGroup.isHidden = true
            
            networkRequestSpinner.isHidden = true
            continueButton.isEnabled = true
            errorLabel.isHidden = false
        }
    }
    
    private func unlockApp() {
        NSApplication.shared.stopModal(withCode: .OK)
        self.view.window?.close()
    }
    
}

extension WaitlistLockScreenViewController: NSTextFieldDelegate {
    
    func controlTextDidChange(_ notification: Notification) {
        if let info = notification.userInfo, let text = info["NSFieldEditor"] as? NSText {
            text.string = text.string.uppercased()
        }
        
        continueButton.isEnabled = !inviteCodeTextField.stringValue.isEmpty
    }
    
}
