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

final class PopoverMessageViewController: NSHostingController<PopoverMessageView> {

    enum Constants {
        static let storyboardName = "MessageViews"
        static let identifier = "PopoverMessageView"
        static let autoDismissDuration: TimeInterval = 2.5
    }

    private var timer: Timer?
    let viewModel: PopoverMessageViewModel
    private var trackingArea: NSTrackingArea?

    init(message: String, image: String? = nil, buttonText: String? = nil, buttonAction: (() -> Void)? = nil) {
        self.viewModel = PopoverMessageViewModel(message: message, image: image, buttonText: buttonText, buttonAction: buttonAction)
        let contentView = PopoverMessageView(viewModel: self.viewModel)
        super.init(rootView: contentView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        cancelAutoDismissTimer()

        if let trackingArea = trackingArea {
            view.removeTrackingArea(trackingArea)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        createTrackingArea()
        scheduleAutoDismissTimer()
    }

    func show(onParent parent: NSViewController, relativeTo view: NSView) {
        let rect = view.bounds

        // Set the content size to match the SwiftUI view's intrinsic size
        self.preferredContentSize = self.view.fittingSize

        parent.present(self,
                       asPopoverRelativeTo: rect,
                       of: view,
                       preferredEdge: .maxY,
                       behavior: .applicationDefined)
    }

    // MARK: - Auto Dismissal
    private func cancelAutoDismissTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleAutoDismissTimer() {
        cancelAutoDismissTimer()
        timer = Timer.scheduledTimer(withTimeInterval: Constants.autoDismissDuration, repeats: false) { [weak self] _ in
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
        cancelAutoDismissTimer()
    }

    override func mouseExited(with event: NSEvent) {
        scheduleAutoDismissTimer()
    }

}
