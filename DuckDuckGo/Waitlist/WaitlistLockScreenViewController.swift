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

final class WaitlistLockScreenViewController: NSViewController {
    
    @IBOutlet var inviteCodeTextField: NSTextField!
    @IBOutlet var continueButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // The unlock screen always uses a light mode appearance, so it's hardcoded here to avoid fighting against
        // system controls that try to display in dark mode.
        view.appearance = NSAppearance(named: .aqua)
    }
    
    @IBAction func quit(_ sender: NSButton) {
        // NSRunningApplication.current.terminate()
        exit(0)
    }
    
    @IBAction func unlock(_ sender: NSButton) {
//        let code = inviteCodeTextField.stringValue
//        let url = URL(string: "https://quackdev.duckduckgo.com/api/auth/invites/macosbrowser/redeem")!
//
//        APIRequest.request(url: url, method: .post, parameters: ["code": code], callBackOnMainThread: true) { result, error  in
//            if let result = result {
//                self.unlockApp()
//            } else {
//                print("Failed")
//            }
//        }
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
