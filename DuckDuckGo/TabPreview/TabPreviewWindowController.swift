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

    enum VerticalSpace: CGFloat {
        case padding = 2
    }

    enum TimerInterval: TimeInterval {
        case short = 0.66
        case medium = 1
        case long = 3
    }

    private var showingTimer: Timer?
    private var hidingTimer: Timer?

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

    func scheduleShowing(parentWindow: NSWindow, timerInterval: TimerInterval, topLeftPointInWindow: CGPoint) {
        if isHiding { return }

        guard let childWindows = parentWindow.childWindows,
              let tabPreviewWindow = self.window else {
            os_log("TabPreviewWindowController: Showing tab preview window failed", type: .error)
            return
        }

        hidingTimer?.invalidate()

        if childWindows.contains(tabPreviewWindow) {
            layout(topLeftPoint: parentWindow.convertPoint(toScreen: topLeftPointInWindow))
            return
        }

        showingTimer?.invalidate()
        showingTimer = Timer.scheduledTimer(withTimeInterval: timerInterval.rawValue, repeats: false, block: { [weak self] _ in
            parentWindow.addChildWindow(tabPreviewWindow, ordered: .above)
            self?.layout(topLeftPoint: parentWindow.convertPoint(toScreen: topLeftPointInWindow))
        })
    }

    func scheduleHiding() {
        showingTimer?.invalidate()

        guard let window = window else {
            os_log("TabPreviewWindowController: Window not available", type: .error)
            return
        }

        if !window.isVisible || hidingTimer?.isValid ?? false { return }

        hidingTimer = Timer.scheduledTimer(withTimeInterval: 1/4, repeats: false, block: { [weak self] _ in
            self?.hide()
        })
    }

    func hide() {
        showingTimer?.invalidate()
        hidingTimer?.invalidate()

        guard let window = window, window.isVisible else {
            return
        }
        guard let parentWindow = window.parent else {
            os_log("TabPreviewWindowController: Tab preview window not available", type: .error)
            return
        }

        isHiding = true
        parentWindow.removeChildWindow(window)
        (window).orderOut(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1/4) { [weak self] in
            if self?.isHiding ?? false { self?.isHiding = false }
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
        hide()
    }

}

extension TabPreviewWindowController.TimerInterval {

    init(from tabWidthStage: TabBarViewItem.WidthStage) {
        switch tabWidthStage {
        case .full: self = .long
        case .withoutCloseButton: self = .medium
        case .withoutTitle: self = .short
        }
    }

}
