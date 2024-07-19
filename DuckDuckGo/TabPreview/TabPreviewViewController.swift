//
//  TabPreviewViewController.swift
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

protocol Previewable {
    var shouldShowPreview: Bool { get }

    var title: String { get }
    var tabContent: Tab.TabContent { get }
    var addressBarString: String { get }
    var snapshot: NSImage? { get }
}

final class TabPreviewViewController: NSViewController {

    enum TextFieldMaskGradientSize: CGFloat {
        case width = 6
        case trailingSpace = 12
    }

    private lazy var viewColorView = ColorView(frame: .zero, backgroundColor: .controlBackgroundColor)
    private lazy var titleTextField = NSTextField()
    private lazy var urlTextField = NSTextField()
    private lazy var box = NSBox()
    private lazy var snapshotImageView = NSImageView()

    private var snapshotImageViewHeightConstraint: NSLayoutConstraint!

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    override func loadView() {
        view = NSView()

        view.addSubview(viewColorView)
        view.addSubview(titleTextField)
        view.addSubview(urlTextField)
        view.addSubview(box)
        view.addSubview(snapshotImageView)

        snapshotImageView.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        snapshotImageView.setContentHuggingPriority(.init(rawValue: 251), for: .vertical)
        snapshotImageView.translatesAutoresizingMaskIntoConstraints = false
        snapshotImageView.imageScaling = .scaleProportionallyDown

        box.boxType = .separator
        box.setContentHuggingPriority(.defaultHigh, for: .vertical)
        box.translatesAutoresizingMaskIntoConstraints = false

        urlTextField.isEditable = false
        urlTextField.isBordered = false
        urlTextField.setContentHuggingPriority(.defaultHigh, for: .vertical)
        urlTextField.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        urlTextField.translatesAutoresizingMaskIntoConstraints = false
        urlTextField.backgroundColor = .textBackgroundColor
        urlTextField.font = .systemFont(ofSize: 13)
        urlTextField.lineBreakMode = .byTruncatingTail
        urlTextField.textColor = .tabPreviewSecondaryTint

        titleTextField.isEditable = false
        titleTextField.isBordered = false
        titleTextField.setContentHuggingPriority(.defaultHigh, for: .vertical)
        titleTextField.setContentHuggingPriority(.init(rawValue: 251), for: .horizontal)
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        titleTextField.backgroundColor = .textBackgroundColor
        titleTextField.font = .systemFont(ofSize: 13, weight: .medium)
        titleTextField.textColor = .tabPreviewTint
        titleTextField.maximumNumberOfLines = 3
        titleTextField.cell?.truncatesLastVisibleLine = true

        viewColorView.translatesAutoresizingMaskIntoConstraints = false

        setupLayout()
    }

    private func setupLayout() {

        viewColorView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        titleTextField.topAnchor.constraint(equalTo: viewColorView.topAnchor, constant: 10).isActive = true
        box.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: snapshotImageView.trailingAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: viewColorView.trailingAnchor).isActive = true
        urlTextField.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 4).isActive = true
        viewColorView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: snapshotImageView.bottomAnchor).isActive = true
        titleTextField.topAnchor.constraint(equalTo: view.topAnchor, constant: 10).isActive = true
        snapshotImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        urlTextField.bottomAnchor.constraint(equalTo: viewColorView.bottomAnchor, constant: -12).isActive = true
        titleTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16).isActive = true
        view.trailingAnchor.constraint(equalTo: box.trailingAnchor).isActive = true
        urlTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16).isActive = true
        view.trailingAnchor.constraint(equalTo: urlTextField.trailingAnchor, constant: 8).isActive = true
        view.trailingAnchor.constraint(equalTo: titleTextField.trailingAnchor, constant: 8).isActive = true
        box.bottomAnchor.constraint(equalTo: viewColorView.bottomAnchor).isActive = true
        snapshotImageView.topAnchor.constraint(equalTo: viewColorView.bottomAnchor).isActive = true

        box.heightAnchor.constraint(equalToConstant: 1).isActive = true

        titleTextField.widthAnchor.constraint(equalToConstant: 256).isActive = true

        viewColorView.heightAnchor.constraint(greaterThanOrEqualToConstant: 57).isActive = true

        snapshotImageViewHeightConstraint = snapshotImageView.heightAnchor.constraint(equalToConstant: 0)
        snapshotImageViewHeightConstraint.isActive = true
    }

    func display(tabViewModel: Previewable, isSelected: Bool) {
        _=view // load view if needed

        titleTextField.stringValue = tabViewModel.title
        titleTextField.lineBreakMode = isSelected ? .byWordWrapping : .byTruncatingTail

        switch tabViewModel.tabContent {
        case .url:
            urlTextField.stringValue = tabViewModel.addressBarString
        case .bookmarks, .dataBrokerProtection, .newtab, .onboarding, .settings, .releaseNotes:
            urlTextField.stringValue = "DuckDuckGo Browser"
        default:
            urlTextField.stringValue = ""
        }

        if !isSelected, tabViewModel.shouldShowPreview, let snapshot = tabViewModel.snapshot {
            snapshotImageView.image = snapshot
            snapshotImageViewHeightConstraint.constant = getHeight(for: snapshot)
        } else {
            snapshotImageView.image = nil
            snapshotImageViewHeightConstraint.constant = 0
        }
    }

    private func getHeight(for image: NSImage?) -> CGFloat {
        guard let image else { return 0 }

        let aspectRatio = image.size.width / image.size.height
        let width = TabPreviewWindowController.width
        let height = width / aspectRatio
        return height
    }

}

extension TabViewModel: Previewable {

    var shouldShowPreview: Bool {
        !isShowingErrorPage
    }

    var snapshot: NSImage? {
        tab.tabSnapshot
    }

    var tabContent: Tab.TabContent {
        tab.content
    }

}

#if DEBUG
extension TabPreviewViewController {
    func displayMockPreview(of size: NSSize, withTitle title: String, content: Tab.TabContent, previewable: Bool, isSelected: Bool) {

        struct PreviewableMock: Previewable {
            let size: NSSize
            let title: String
            var tabContent: Tab.TabContent
            let shouldShowPreview: Bool
            var addressBarString: String { tabContent.userEditableUrl?.absoluteString ?? "Default" }

            var snapshot: NSImage? {
                let image = NSImage(size: size)
                image.lockFocus()
                NSColor(deviceRed: 0.95, green: 0.98, blue: 0.99, alpha: 1).setFill()
                NSRect(origin: .zero, size: image.size).fill()
                image.unlockFocus()
                return image
            }
        }

        self.display(tabViewModel: PreviewableMock(size: size, title: title, tabContent: content, shouldShowPreview: previewable), isSelected: isSelected)
    }
}

import Combine

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 280, height: 220)) { {

    let vc = TabPreviewViewController()
    vc.displayMockPreview(of: NSSize(width: 1280, height: 560),
                          withTitle: "Some reasonably long tab preview title that won‘t fit in one line",
                          content: .url(.makeSearchUrl(from: "SERP query string to search for some ducks")!, source: .ui),
                          previewable: true,
                          isSelected: true)

    var c: AnyCancellable!
    c = vc.publisher(for: \.view.window).sink { window in
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.styleMask = []
        window?.setFrame(NSRect(origin: .zero, size: vc.view.bounds.size), display: true)
        withExtendedLifetime(c) {}
    }

    return vc

}() }
#endif
