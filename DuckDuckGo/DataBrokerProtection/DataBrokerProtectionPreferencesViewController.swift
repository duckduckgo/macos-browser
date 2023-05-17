//
//  DataBrokerProtectionPreferencesViewController.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

final class DataBrokerProtectionPreferencesViewController: NSViewController {
    var handler: DataBrokerWebViewHandler?

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        handler = DataBrokerWebViewHandler(delegate: self)

        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.red.cgColor

        let button = NSButton(frame: NSRect(x: 150, y: 200, width: 80, height: 55))
        button.title =  "A button in code"
        button.target = self
        button.action = #selector(buttonAction)
        view.addSubview(button)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
    }

    @objc func buttonAction(sender: NSButton!) {
        handler?.test()
    }
}

extension DataBrokerProtectionPreferencesViewController: DataBrokerMessagingDelegate {

    func ready() {
        self.handler?.sendAction()
    }

    func evaluateJavascript(javascript: String) {
        self.handler?.webView?.evaluateJavaScript(javascript)
    }
}
