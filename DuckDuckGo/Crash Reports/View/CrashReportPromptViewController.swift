//
//  CrashReportPromptViewController.swift
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

#if OUT_OF_APPSTORE

protocol CrashReportPromptViewControllerDelegate: AnyObject {

    func crashReportPromptViewController(_ crashReportPromptViewController: CrashReportPromptViewController,
                                         userDidAllowToReport: Bool)

}

final class CrashReportPromptViewController: NSViewController {

    @IBOutlet var textView: NSTextView!

    weak var delegate: CrashReportPromptViewControllerDelegate?
    var crashReport: CrashReport? {
        didSet {
            updateView()
        }
    }

    private func updateView() {
        guard let content = crashReport?.content else {
            assertionFailure("CrashReportPromptViewController: Failed to get content")
            return
        }

        textView?.string = content
    }

    @IBAction func sendAction(_ sender: Any) {
        delegate?.crashReportPromptViewController(self, userDidAllowToReport: true)
        view.window?.close()
    }

    @IBAction func dontSendAction(_ sender: Any) {
        delegate?.crashReportPromptViewController(self, userDidAllowToReport: false)
        view.window?.close()
    }
    
}

#endif
