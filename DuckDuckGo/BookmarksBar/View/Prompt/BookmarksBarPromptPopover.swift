//
//  BookmarksBarPromptPopover.swift
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

import Foundation
import SwiftUI
import SwiftUIExtensions

final class BookmarksBarPromptPopover: NSPopover {

    override init() {
        super.init()
        self.behavior = .semitransient
        self.delegate = self
        setupContentController()
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    // swiftlint:disable force_cast
    var viewController: BookmarksBarPromptViewController { contentViewController as! BookmarksBarPromptViewController }
    // swiftlint:enable force_cast

    private func setupContentController() {
        let controller = BookmarksBarPromptViewController.create()
        contentViewController = controller
        contentViewController?.preferredContentSize = NSSize(width: 356, height: 272)
    }

}

extension BookmarksBarPromptPopover: NSPopoverDelegate {

    func popoverDidClose(_ notification: Notification) {
        if !viewController.rootView.model.userDidDismiss {
            viewController.rootView.model.delegate?.rejectBookmarksBar()
        }
    }

}

final class BookmarksBarPromptViewController: NSHostingController<BookmarksBarPromptView> {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    static func create() -> BookmarksBarPromptViewController {
        let controller = BookmarksBarPromptViewController(rootView: BookmarksBarPromptView())
        controller.rootView.model.delegate = controller
        return controller
    }

}

extension BookmarksBarPromptViewController: BookmarksBarPromptDelegate {

    func rejectBookmarksBar() {
        AppearancePreferences.shared.showBookmarksBar = false
        dismiss()
    }

    func acceptBookmarksBar() {
        AppearancePreferences.shared.showBookmarksBar = true
        dismiss()
    }

}

struct BookmarksBarPromptView: View {

    @ObservedObject var model = BookmarksBarPromptViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Image("BookmarksBarIllustration")
                .padding(.bottom, 16)

            Text("Show Bookmarks Bar for quick access to your bookmarks")
                .font(Font.custom("SF Pro Text", size: 15)
                    .weight(.semibold))
                .padding(.bottom, 16)

            Text("Manage Bookmarks Bar in Settings > Appearance.")
                .font(Font.custom("SF Pro Text", size: 13))
                .padding(.bottom, 20)

            HStack {
                Button {
                    model.onNotNow()
                } label: {
                    Text("Not Now")
                        .font(Font.custom("SF Pro Text", size: 13))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                }
                .buttonStyle(StandardButtonStyle())
                .padding(0)

                Button {
                    model.onShow()
                } label: {
                    Text("Show")
                        .font(Font.custom("SF Pro Text", size: 13))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)

                }
                .buttonStyle(DefaultActionButtonStyle(enabled: true))
                .padding(0)
            }

        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("InterfaceBackgroundColor"))
    }

}

final class BookmarksBarPromptViewModel: ObservableObject {

    weak var delegate: BookmarksBarPromptDelegate?

    var userDidDismiss = false

    func onNotNow() {
        userDidDismiss = true
        delegate?.rejectBookmarksBar()
    }

    func onShow() {
        userDidDismiss = true
        delegate?.acceptBookmarksBar()
    }

}

protocol BookmarksBarPromptDelegate: AnyObject {

    func rejectBookmarksBar()

    func acceptBookmarksBar()

}
