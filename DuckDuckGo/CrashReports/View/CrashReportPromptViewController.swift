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

final class CrashReportPromptViewController: NSViewController {
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var dontSendButton: NSButton!
    @IBOutlet weak var sendButton: NSButton!
    @IBOutlet weak var textFieldTitle: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    @IBOutlet var textView: NSTextView!

    var userDidAllowToReport: () -> Void = {}

    var crashReport: CrashReportPresenting? {
        didSet {
            updateView()
        }
    }

    override func viewDidLoad() {
        titleLabel.stringValue = UserText.crashReportTitle
        descriptionLabel.stringValue = UserText.crashReportDescription
        sendButton.title = UserText.crashReportSendButton
        dontSendButton.title = UserText.crashReportDontSendButton
        textFieldTitle.stringValue = UserText.crashReportTextFieldTitle
    }

    private func updateView() {
        guard let content = crashReport?.content else {
            assertionFailure("CrashReportPromptViewController: Failed to get content")
            return
        }

        textView?.string = content
    }

    @IBAction func sendAction(_ sender: Any) {
        userDidAllowToReport()
        view.window?.close()
    }

    @IBAction func dontSendAction(_ sender: Any) {
        view.window?.close()
    }

}
