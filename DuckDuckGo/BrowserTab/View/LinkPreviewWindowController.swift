//
//  LinkPreviewWindowController.swift
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

import Foundation

class LinkPreviewWindowController: NSWindowController, NSWindowDelegate {

    private var canGoBack: Bool = false
    private var canGoForward: Bool = false

    init() {
        super.init(window: nil)

        Bundle.main.loadNibNamed("LinkPreviewWindowController", owner: self, topLevelObjects: nil)

        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.isMovableByWindowBackground = true
        // window?.backgroundColor = .lightGray
        window?.isOpaque = false
        window?.styleMask = [.resizable, .titled, .fullSizeContentView]
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.showsToolbarButton = false
        window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window?.standardWindowButton(.closeButton)?.isHidden = true
        window?.standardWindowButton(.zoomButton)?.isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        window!.makeKeyAndOrderFront(sender)
        LinkPreviewWindowControllerManager.shared.register(self)
    }

    func windowWillClose(_ notification: Notification) {
        guard contentViewController is LinkPreviewViewController else {
            return
        }

        window?.resignKey()
        window?.resignMain()

        DispatchQueue.main.async {
            LinkPreviewWindowControllerManager.shared.unregister(self)
        }
    }

}

class LinkPreviewWindowControllerManager {

    static let shared = LinkPreviewWindowControllerManager()

    private(set) var windowControllers = [LinkPreviewWindowController]()

    func register(_ windowController: LinkPreviewWindowController) {
        windowControllers.append(windowController)
    }

    func unregister(_ windowController: LinkPreviewWindowController) {
        guard let index = windowControllers.firstIndex(of: windowController) else {
            return
        }

        windowControllers.remove(at: index)
    }

}
