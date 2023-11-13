//
//  ZoomPopover.swift
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

import SwiftUI
import Combine

struct ZoomPopoverContentView: View {
    @ObservedObject var viewModel: ZoomPopoverViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(viewModel.zoomLevel.displayString)
                .frame(width: 96, height: 28)
            Spacer()
            Text("Reset")
                . background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color("BlackWhite10"))
                        .frame(width: 64, height: 28)
                )
                .onTapGesture {
                    viewModel.reset()
                }
                .frame(width: 64, height: 28)

            HStack(spacing: 0) {
                Image("minus")
                    .onTapGesture {
                        viewModel.zoomOut()
                    }
                    .frame(width: 32, height: 28)
                Rectangle()
                    .fill(Color("BlackWhite50"))
                    .frame(width: 1, height: 28)
                Image("plus")
                    .onTapGesture {
                        viewModel.zoomIn()
                    }
                    .frame(width: 32, height: 28)
            }
            . background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color("BlackWhite10"))
                    .frame(width: 64, height: 28)
            )
            .frame(width: 66, height: 28)

        }
        .padding(12)
        .padding(.leading, 8)
        .frame(width: 288, height: 52)
    }
}

final class ZoomPopoverViewModel: ObservableObject {
    let appearancePreferences: AppearancePreferences
    let tabViewModel: TabViewModel
    @Published var zoomLevel: DefaultZoomValue = .percent100
    private var cancellables = Set<AnyCancellable>()

    init(appearancePreferences: AppearancePreferences, tabViewModel: TabViewModel) {
        self.appearancePreferences = appearancePreferences
        self.tabViewModel = tabViewModel
        guard let urlString = tabViewModel.tab.url?.absoluteString else { return }
        zoomLevel = appearancePreferences.zoomPerWebsite(url: urlString) ?? .percent100
        NotificationCenter.default.publisher(for: AppearancePreferences.zoomPerWebsiteUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if let newZoomLevel = appearancePreferences.zoomPerWebsite(url: urlString) {
                    self?.zoomLevel = newZoomLevel
                }
            }.store(in: &cancellables)
        appearancePreferences.$defaultPageZoom.sink { [weak self] newValue in
            guard let self = self else { return }
            if appearancePreferences.zoomPerWebsite(url: urlString) == nil {
                zoomLevel = newValue
            }
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

        frame = frame.insetBy(dx: -36, dy: -window.frame.size.height)

        return frame
    }

    init(tabViewModel: TabViewModel) {
        self.tabViewModel = tabViewModel
        super.init()

        self.animates = false
        self.behavior = .transient
        setupContentController()
    }

    required init?(coder: NSCoder) {
        fatalError("BookmarksPopover: Bad initializer")
    }

    // swiftlint:disable force_cast
    var viewController: BookmarkPopoverViewController { contentViewController as! BookmarkPopoverViewController }
    // swiftlint:enable force_cast

    private func setupContentController() {
        let controller = ZoomPopoverViewController(viewModel: ZoomPopoverViewModel(appearancePreferences: AppearancePreferences.shared, tabViewModel: tabViewModel))
        contentViewController = controller
    }

    override func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        self.addressBar = positioningView.superview
        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }

}
