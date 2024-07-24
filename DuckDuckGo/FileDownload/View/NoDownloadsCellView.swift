//
//  NoDownloadsCellView.swift
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

final class NoDownloadsCellView: NSTableCellView {

    fileprivate enum Constants {
        static let viewSize = CGSize(width: 420, height: 60)
    }

    private let titleLabel = NSTextField(string: UserText.downloadsNoRecentDownload)
    private let openFolderButton = LinkButton(title: UserText.downloadsOpenDownloadsFolder,
                                              target: nil,
                                              action: #selector(DownloadsViewController.openDownloadsFolderAction))

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: CGRect(origin: .zero, size: Constants.viewSize))
        self.identifier = identifier

        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    private func setupUI() {
        addSubview(titleLabel)
        addSubview(openFolderButton)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.isSelectable = false
        titleLabel.drawsBackground = false
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingMiddle

        openFolderButton.translatesAutoresizingMaskIntoConstraints = false
        openFolderButton.bezelStyle = .shadowlessSquare
        openFolderButton.isBordered = false
        openFolderButton.alignment = .center
        openFolderButton.font = .systemFont(ofSize: 13)
        openFolderButton.contentTintColor = .linkColor

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            openFolderButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor,
                                                  constant: 4),
            openFolderButton.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

}

@available(macOS 14.0, *)
#Preview(traits: NoDownloadsCellView.Constants.viewSize.fixedLayout) {
    PreviewViewController(showWindowTitle: false) {
        NoDownloadsCellView(identifier: .init(""))
    }
}
