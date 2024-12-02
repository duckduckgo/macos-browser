//
//  PopoverMessageViewController.swift
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
import SwiftUI
import SwiftUIExtensions
final class PopoverMessageViewController: NSHostingController<PopoverMessageView>, NSPopoverDelegate {

    enum Constants {
        static let storyboardName = "MessageViews"
        static let identifier = "PopoverMessageView"
        static let autoDismissDuration: TimeInterval = 2.5
    }

    let viewModel: PopoverMessageViewModel
    let onDismiss: (() -> Void)?
    let autoDismissDuration: TimeInterval?
    let onClick: (() -> Void)?
    private var timer: Timer?
    private var trackingArea: NSTrackingArea?

    init(title: String? = nil,
         message: String,
         image: NSImage? = nil,
         buttonText: String? = nil,
         buttonAction: (() -> Void)? = nil,
         shouldShowCloseButton: Bool = false,
         presentMultiline: Bool = false,
         autoDismissDuration: TimeInterval? = Constants.autoDismissDuration,
         onDismiss: (() -> Void)? = nil,
         onClick: (() -> Void)? = nil) {
        self.viewModel = PopoverMessageViewModel(title: title,
                                                 message: message,
                                                 image: image,
                                                 buttonText: buttonText,
                                                 buttonAction: buttonAction,
                                                 shouldShowCloseButton: shouldShowCloseButton,
                                                 shouldPresentMultiline: presentMultiline)
        self.onDismiss = onDismiss
        self.autoDismissDuration = autoDismissDuration
        self.onClick = onClick
        let contentView = PopoverMessageView(viewModel: self.viewModel, onClick: { }, onClose: { })
        super.init(rootView: contentView)
        self.rootView = createContentView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        cancelAutoDismissTimer()

        if let trackingArea = trackingArea {
            view.removeTrackingArea(trackingArea)
        }
        onDismiss?()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        createTrackingArea()
        scheduleAutoDismissTimer()
    }

    func show(onParent parent: NSViewController, rect: NSRect, of view: NSView, preferredEdge: NSRectEdge = .maxY) {
        // Set the content size to match the SwiftUI view's intrinsic size
        self.preferredContentSize = self.view.fittingSize
        // For shorter strings, the positioning can be off unless the width is set a second time
        self.preferredContentSize.width = self.view.fittingSize.width

        parent.present(self,
                       asPopoverRelativeTo: rect,
                       of: view,
                       preferredEdge: preferredEdge,
                       behavior: .applicationDefined)
    }

    func show(onParent parent: NSViewController,
              relativeTo view: NSView,
              preferredEdge: NSRectEdge = .maxY,
              behavior: NSPopover.Behavior = .applicationDefined) {
        // Set the content size to match the SwiftUI view's intrinsic size
        self.preferredContentSize = self.view.fittingSize
        // For shorter strings, the positioning can be off unless the width is set a second time
        self.preferredContentSize.width = self.view.fittingSize.width

        parent.present(self,
                       asPopoverRelativeTo: self.view.bounds,
                       of: view,
                       preferredEdge: preferredEdge,
                       behavior: behavior)
    }

    // MARK: - Auto Dismissal
    private func cancelAutoDismissTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleAutoDismissTimer() {
        cancelAutoDismissTimer()
        if let autoDismissDuration {
            timer = Timer.scheduledTimer(withTimeInterval: autoDismissDuration, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.presentingViewController?.dismiss(self)
            }
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
        cancelAutoDismissTimer()
    }

    override func mouseExited(with event: NSEvent) {
        scheduleAutoDismissTimer()
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
        dismissPopover()
    }

    private func dismissPopover() {
        presentingViewController?.dismiss(self)
    }

    private func createContentView() -> PopoverMessageView {
        return PopoverMessageView(viewModel: self.viewModel, onClick: { [weak self] in
            self?.onClick?()
        }) { [weak self] in
            self?.dismissPopover()
        }
    }
}
