//
//  TabPreviewWindowController.swift
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
import Common

final class TabPreviewWindowController: NSWindowController {

    enum Size: CGFloat {
        case width = 280
    }

    enum VerticalSpace: CGFloat {
        case padding = 2
    }

    enum Delay: Double {
        case standard = 1.5
    }

    private var previewTimer: Timer?
    private var lastHideTime: Date?

    private var isHiding = false

    // swiftlint:disable force_cast
    var tabPreviewViewController: TabPreviewViewController {
        contentViewController as! TabPreviewViewController
    }
    // swiftlint:enable force_cast

    override func windowDidLoad() {
        super.windowDidLoad()

        window?.animationBehavior = .utilityWindow
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(suggestionWindowOpenNotification(_:)),
                                               name: .suggestionWindowOpen,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show(parentWindow: NSWindow, topLeftPointInWindow: CGPoint) {
        func presentPreview(tabPreviewWindow: NSWindow) {
            parentWindow.addChildWindow(tabPreviewWindow, ordered: .above)
            self.layout(topLeftPoint: parentWindow.convertPoint(toScreen: topLeftPointInWindow))
        }

        guard let childWindows = parentWindow.childWindows,
              let tabPreviewWindow = self.window else {
            os_log("TabPreviewWindowController: Showing tab preview window failed", type: .error)
            return
        }

        if childWindows.contains(tabPreviewWindow) {
            layout(topLeftPoint: parentWindow.convertPoint(toScreen: topLeftPointInWindow))
            return
        }

        // Check time elapsed since last hide
        if let lastHide = lastHideTime, Date().timeIntervalSince(lastHide) < Delay.standard.rawValue {
            // Show immediately if less than 1.5 seconds have passed
            presentPreview(tabPreviewWindow: tabPreviewWindow)
        } else {
            // Set up a new timer for normal delayed presentation
            previewTimer?.invalidate()
            previewTimer = Timer.scheduledTimer(withTimeInterval: Delay.standard.rawValue, repeats: false) { _ in
                presentPreview(tabPreviewWindow: tabPreviewWindow)
            }
        }

    }

    func hide(allowQuickRedisplay: Bool) {
        func removePreview() -> Bool {
            guard let window = window, window.isVisible else {
                return false
            }
            guard let parentWindow = window.parent else {
                os_log("TabPreviewWindowController: Tab preview window not available", type: .error)
                return false
            }

            parentWindow.removeChildWindow(window)
            (window).orderOut(nil)

            return true
        }
        previewTimer?.invalidate()

        // Hide the preview
        if removePreview() {
            // Record the hide time
            lastHideTime = allowQuickRedisplay ? Date() : nil
        }
    }

    private func layout(topLeftPoint: NSPoint) {
        guard let window = window else {
            os_log("TabBarCollectionView: Tab preview window not available", type: .error)
            return
        }

        window.setFrame(NSRect(x: 0, y: 0, width: 250, height: 58), display: true)
        window.setFrameTopLeftPoint(topLeftPoint)
    }

}

extension TabPreviewWindowController {

    @objc func suggestionWindowOpenNotification(_ notification: Notification) {
        hide(allowQuickRedisplay: false)
    }

}
