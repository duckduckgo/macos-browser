//
//  NSViewControllerExtension.swift
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

extension NSViewController {

    /// Applies a modal window style to a view controller if it is being presented by another view controller.
    func applyModalWindowStyleIfNeeded() {
        guard self.presentingViewController != nil else { return }

        self.view.window?.titleVisibility = .hidden
        self.view.window?.titlebarAppearsTransparent = true
        self.view.window?.standardWindowButton(.zoomButton)?.isHidden = true
        self.view.window?.standardWindowButton(.closeButton)?.isHidden = true
        self.view.window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.view.window?.styleMask = [.resizable, .titled, .fullSizeContentView]
    }

    func wrappedInWindowController() -> NSWindowController {
        let window = NSWindow(contentViewController: self)
        return NSWindowController(window: window)
    }

    func beginSheet(_ windowController: NSWindowController) {
        if let windowSheet = windowController.window {
            view.window?.beginSheet(windowSheet)
        }
    }

    func beginSheet(_ viewController: NSViewController, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
        let windowController = viewController.wrappedInWindowController()

        if let windowSheet = windowController.window {
            view.window?.beginSheet(windowSheet, completionHandler: handler)
        }
    }

    func dismiss() {
        guard let window = view.window else {
            assertionFailure("\(#file): Failed to get the view's window")
            return
        }

        if let sheetParent = window.sheetParent {
            sheetParent.endSheet(window, returnCode: .cancel)
        } else if let presentingViewController = presentingViewController {
            presentingViewController.dismiss(self)
        } else if let popover = nextResponder as? NSPopover {
            popover.close()
        } else {
            assertionFailure("dismiss() called not properly")
        }
    }

    func removeCompletely() {
        guard parent != nil else { return }
        removeFromParent()
        view.removeFromSuperview()
    }

    func withoutAnimation(_ closure: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        closure()
        CATransaction.commit()
    }
}
