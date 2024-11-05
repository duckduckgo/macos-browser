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
import os.log

final class TabPreviewWindowController: NSWindowController {

    static let width: CGFloat = 280
    static let padding: CGFloat = 2
    static let bottomPadding: CGFloat = 40
    static let delay: CGFloat = 1

    private var previewTimer: Timer?
    private var hideTimer: Timer?
    private var lastHideTime: Date?

    private var isHiding = false

    // swiftlint:disable force_cast
    var tabPreviewViewController: TabPreviewViewController {
        return self.window!.contentViewController as! TabPreviewViewController
    }
    // swiftlint:enable force_cast

    init() {
        super.init(window: Self.loadWindow())

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(suggestionWindowOpenNotification(_:)),
                                               name: .suggestionWindowOpen,
                                               object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    private static func loadWindow() -> NSWindow {
        let tabPreviewViewController = TabPreviewViewController()

        let window = NSWindow(contentRect: CGRect(x: 294, y: 313, width: 280, height: 58), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: true)
        window.contentViewController = tabPreviewViewController

        window.allowsToolTipsWhenApplicationIsInactive = false
        window.autorecalculatesKeyViewLoop = false
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.animationBehavior = .utilityWindow

        return window
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show(parentWindow: NSWindow, topLeftPointInWindow: CGPoint) {
        Logger.tabPreview.log("Showing tab preview")

        func presentPreview(tabPreviewWindow: NSWindow) {
            Logger.tabPreview.log("Presenting tab preview")

            parentWindow.addChildWindow(tabPreviewWindow, ordered: .above)
            self.layout(topLeftPoint: parentWindow.convertPoint(toScreen: topLeftPointInWindow))
        }

        // Invalidate hide timer if it exists
        hideTimer?.invalidate()

        guard let childWindows = parentWindow.childWindows,
              let tabPreviewWindow = self.window else {
            Logger.general.error("Showing tab preview window failed")
            return
        }

        if childWindows.contains(tabPreviewWindow) {
            layout(topLeftPoint: parentWindow.convertPoint(toScreen: topLeftPointInWindow))
            return
        }

        // Check time elapsed since last hide
        if let lastHide = lastHideTime, Date().timeIntervalSince(lastHide) < Self.delay {
            // Show immediately if less than 1.5 seconds have passed
            presentPreview(tabPreviewWindow: tabPreviewWindow)
        } else {
            // Set up a new timer for normal delayed presentation
            previewTimer?.invalidate()
            previewTimer = Timer.scheduledTimer(withTimeInterval: Self.delay, repeats: false) { _ in
                presentPreview(tabPreviewWindow: tabPreviewWindow)
            }
        }

    }

    func hide(allowQuickRedisplay: Bool = false, withDelay delay: Bool = false) {
        Logger.tabPreview.log("Hiding tab preview allowQuickRedisplay:\(allowQuickRedisplay) delay:\(delay)")

        func removePreview(allowQuickRedisplay: Bool) {
            Logger.tabPreview.log("Removing tab preview allowQuickRedisplay:\(allowQuickRedisplay)")

            guard let window = window else {
                lastHideTime = nil
                return
            }

            guard let parentWindow = window.parent else {
                if !allowQuickRedisplay {
                    lastHideTime = nil
                }
                window.orderOut(nil)
                return
            }

            parentWindow.removeChildWindow(window)
            window.orderOut(nil)

            // Record the hide time
            lastHideTime = allowQuickRedisplay ? Date() : nil
        }

        previewTimer?.invalidate()

        if delay {
            // Set up a new timer to hide the preview after 0.05 seconds
            // It makes the transition from one preview to another more fluent
            hideTimer?.invalidate()
            hideTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { _ in
                removePreview(allowQuickRedisplay: allowQuickRedisplay)
            }
        } else {
            // Hide the preview immediately
            removePreview(allowQuickRedisplay: allowQuickRedisplay)
        }
    }

    private func layout(topLeftPoint: NSPoint) {
        guard let window = window else {
            return
        }
        var topLeftPoint = topLeftPoint

        // Make sure preview is presented within screen
        if let screenVisibleFrame = window.screen?.visibleFrame {
            topLeftPoint.x = min(topLeftPoint.x, screenVisibleFrame.origin.x + screenVisibleFrame.width - window.frame.width)
            topLeftPoint.x = max(topLeftPoint.x, screenVisibleFrame.origin.x)

            let windowHeight = window.frame.size.height
            if topLeftPoint.y <= windowHeight + screenVisibleFrame.origin.y {
                topLeftPoint.y = topLeftPoint.y + windowHeight + Self.bottomPadding
            }
        }

        window.setFrameTopLeftPoint(topLeftPoint)
    }

}

extension TabPreviewWindowController {

    @objc func suggestionWindowOpenNotification(_ notification: Notification) {
        hide(allowQuickRedisplay: false)
    }

}
