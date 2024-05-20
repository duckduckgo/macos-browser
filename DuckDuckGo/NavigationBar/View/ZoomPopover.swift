//
//  ZoomPopover.swift
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

import SwiftUI
import Combine

struct ZoomPopoverContentView: View {
    @ObservedObject var viewModel: ZoomPopoverViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(viewModel.zoomLevel.displayString)
                .frame(width: 50, height: 28)
                .padding(.horizontal, 8)

            Button {
                viewModel.reset()
            } label: {
                Text(UserText.resetZoom)
                    .frame(height: 28)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
            }

            HStack(spacing: 1) {
                Button {
                    viewModel.zoomOut()
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 32, height: 28)
                }
                Button {
                    viewModel.zoomIn()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 32, height: 28)
                }
            }
        }
        .frame(height: 52)
        .padding(.horizontal, 16)
    }
}

final class ZoomPopoverViewModel: ObservableObject {
    let tabViewModel: TabViewModel
    @Published var zoomLevel: DefaultZoomValue = .percent100
    private var cancellables = Set<AnyCancellable>()

    init(tabViewModel: TabViewModel) {
        self.tabViewModel = tabViewModel
        zoomLevel = tabViewModel.zoomLevel
        tabViewModel.zoomLevelSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.zoomLevel = newValue
            }.store(in: &cancellables)
    }

    func zoomIn() {
        tabViewModel.tab.webView.zoomIn()
    }

    func zoomOut() {
        tabViewModel.tab.webView.zoomOut()
    }

    func reset() {
        tabViewModel.tab.webView.resetZoomLevel()
    }

}

final class ZoomPopoverViewController: NSViewController {
    let viewModel: ZoomPopoverViewModel

    init(viewModel: ZoomPopoverViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let swiftUIView = ZoomPopoverContentView(viewModel: viewModel)
        view = NSHostingView(rootView: swiftUIView)
    }
}

final class ZoomPopover: NSPopover {

    var tabViewModel: TabViewModel

    private weak var addressBar: NSView?

    /// prefferred bounding box for the popover positioning
    override var boundingFrame: NSRect {
        guard let addressBar,
              let window = addressBar.window else { return .infinite }
        var frame = window.convertToScreen(addressBar.convert(addressBar.bounds, to: nil))
        frame = frame.insetBy(dx: 0, dy: -window.frame.size.height)
        return frame
    }

    /// position popover to the right
    override func adjustFrame(_ frame: NSRect) -> NSRect {
        let boundingFrame = self.boundingFrame
        guard !boundingFrame.isInfinite else { return frame }
        var frame = frame
        frame.origin.x = boundingFrame.minX
        return frame
    }

    init(tabViewModel: TabViewModel) {
        self.tabViewModel = tabViewModel
        super.init()

        self.animates = false
        self.behavior = .semitransient
        setupContentController()
    }

    required init?(coder: NSCoder) {
        fatalError("BookmarksPopover: Bad initializer")
    }

    // swiftlint:disable force_cast
    var viewController: ZoomPopoverViewController { contentViewController as! ZoomPopoverViewController }
    // swiftlint:enable force_cast

    private func setupContentController() {
        let controller = ZoomPopoverViewController(viewModel: ZoomPopoverViewModel(tabViewModel: tabViewModel))
        contentViewController = controller
    }

    override func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        self.addressBar = positioningView.superview
        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }
}
