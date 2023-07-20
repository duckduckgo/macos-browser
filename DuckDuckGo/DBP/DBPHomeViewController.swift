//
//  DBPHomeViewController.swift
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

import Foundation
import DataBrokerProtection
import AppKit

final class DBPHomeViewController: NSViewController {
    private lazy var debugWindow: NSWindow = {
        let windowRect = NSRect(x: 0, y: 0, width: 1024, height: 768)
        let window = NSWindow(contentRect: windowRect,
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered,
                              defer: false)
        window.title = "Debug Window"
        window.center()

        let debugViewController = DataBrokerProtectionDebugViewController()
        window.contentViewController = debugViewController

        return window
    }()

    lazy var dataBrokerContainerView: DataBrokeContainerViewController = {
        DataBrokeContainerViewController()
    }()

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(dataBrokerContainerView)
        view.addSubview(dataBrokerContainerView.view)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        openDebugUI()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        dataBrokerContainerView.view.frame = view.bounds
    }

    private func openDebugUI() {
        debugWindow.makeKeyAndOrderFront(nil)
    }
}
