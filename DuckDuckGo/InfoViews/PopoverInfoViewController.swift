//
//  PopoverInfoViewController.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import SwiftUI
import SwiftUIExtensions

final class PopoverInfoViewController: NSHostingController<InfoView> {

    enum Constants {
        static let autoDismissDuration: TimeInterval = 0.5
    }

    let onDismiss: (() -> Void)?
    let autoDismissDuration: TimeInterval
    private var timer: Timer?
    private var trackingArea: NSTrackingArea?

    init(message: String,
         autoDismissDuration: TimeInterval = Constants.autoDismissDuration,
         onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
        self.autoDismissDuration = autoDismissDuration
        super.init(rootView: InfoView(info: message))
        let popoverBackground = PopoverInfoContentView()
        view.addSubview(popoverBackground, positioned: .below, relativeTo: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        cancelAutoDismiss()
        onDismiss?()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        scheduleAutoDismiss()
        createTrackingArea()
    }

    func show(onParent parent: NSViewController, rect: NSRect, of view: NSView) {
        // Set the content size to match the SwiftUI view's intrinsic size
        self.preferredContentSize = self.view.fittingSize

        parent.present(self,
                       asPopoverRelativeTo: rect,
                       of: view,
                       preferredEdge: .maxY,
                       behavior: .applicationDefined)
    }

    func show(onParent parent: NSViewController, relativeTo view: NSView) {
        // Set the content size to match the SwiftUI view's intrinsic size
        self.preferredContentSize = self.view.fittingSize
        // For shorter strings, the positioning can be off unless the width is set a second time
        self.preferredContentSize.width = self.view.fittingSize.width

        parent.present(self,
                       asPopoverRelativeTo: self.view.bounds,
                       of: view,
                       preferredEdge: .maxY,
                       behavior: .applicationDefined)
        let presentingViewTrackingArea = NSTrackingArea(rect: self.view.convert(self.view.frame, from: view),
                                                        options: [.mouseEnteredAndExited, .activeInKeyWindow],
                                                        owner: self)
        view.addTrackingArea(presentingViewTrackingArea)
    }

    // MARK: - Auto Dismissal
    func cancelAutoDismiss() {
        timer?.invalidate()
        timer = nil
    }

    func scheduleAutoDismiss() {
        cancelAutoDismiss()
        timer = Timer.scheduledTimer(withTimeInterval: autoDismissDuration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.presentingViewController?.dismiss(self)
        }
    }

    // MARK: - Mouse Tracking
    private func createTrackingArea() {
        trackingArea = NSTrackingArea(rect: view.bounds,
                                      options: [.mouseEnteredAndExited, .activeInKeyWindow],
                                      owner: self,
                                      userInfo: nil)
        view.addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        cancelAutoDismiss()
    }

    override func mouseExited(with event: NSEvent) {
        scheduleAutoDismiss()
    }

    override func mouseDown(with event: NSEvent) {
        dismissPopover()
    }

    private func dismissPopover() {
        presentingViewController?.dismiss(self)
    }
}

struct InfoView: View {
    let info: String

    var body: some View {
        Text(.init(info))
            .onURLTap { url in
                if let pane = PreferencePaneIdentifier(url: url) {
                    WindowControllersManager.shared.showPreferencesTab(withSelectedPane: pane)
                } else {
                    WindowControllersManager.shared.showTab(with: .url(url, source: .link))
                }
            }
            .padding(16)
            .frame(width: 250, alignment: .leading)
            .frame(minHeight: 22)
            .lineLimit(nil)
    }
}

private final class PopoverInfoContentView: NSView {
    var backgroundView: PopoverInfoBackgroundView?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let frameView = self.window?.contentView?.superview {
            if backgroundView == nil {
                backgroundView = PopoverInfoBackgroundView(frame: frameView.bounds)
                backgroundView!.autoresizingMask = NSView.AutoresizingMask([.width, .height])
                frameView.addSubview(backgroundView!, positioned: NSWindow.OrderingMode.below, relativeTo: frameView)
            }
        }
    }
}

private final class PopoverInfoBackgroundView: NSView {
    var backgroundColor: NSColor = NSColor.controlColor {
        didSet {
            draw(bounds)
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        backgroundColor.set()
        self.bounds.fill()
    }
}
