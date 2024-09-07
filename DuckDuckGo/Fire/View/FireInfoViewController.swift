//
//  FireInfoViewController.swift
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

import Cocoa

protocol FireInfoViewControllerDelegate: AnyObject {

    func fireInfoViewControllerDidConfirm(_ fireInfoViewController: FireInfoViewController)

}

final class FireInfoViewController: NSViewController {

    private lazy var titleLabel = NSTextField(string: UserText.fireInfoDialogTitle)
    private lazy var descriptionLabel = NSTextField(wrappingLabelWithString: UserText.fireInfoDialogDescription)
    private lazy var gotItButton = NSButton(title: UserText.gotIt, target: self, action: #selector(gotItAction))
    private lazy var imageView = NSImageView(image: .fireHeader)

    weak var delegate: FireInfoViewControllerDelegate?

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("FireInfoViewController: Bad initializer")
    }

    override func loadView() {
        view = ColorView(frame: .zero, backgroundColor: .interfaceBackground)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.alignment = .center
        titleLabel.isEditable = false
        titleLabel.isSelectable = false
        titleLabel.isBordered = false
        titleLabel.drawsBackground = false
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .greyText

        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.alignment = .center
        descriptionLabel.isEditable = false
        descriptionLabel.isSelectable = false
        descriptionLabel.isBordered = false
        descriptionLabel.drawsBackground = false
        descriptionLabel.usesSingleLineMode = false
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.font = .systemFont(ofSize: 13)
        descriptionLabel.textColor = .greyText

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.alignment = .left
        imageView.imageScaling = .scaleProportionallyDown

        gotItButton.translatesAutoresizingMaskIntoConstraints = false
        gotItButton.alignment = .center
        gotItButton.bezelStyle = .rounded
        gotItButton.controlSize = .large
        gotItButton.font = .systemFont(ofSize: 13)
        gotItButton.imageScaling = .scaleProportionallyDown
        gotItButton.isBordered = true
        gotItButton.keyEquivalent = "\r"

        view.addSubview(gotItButton)
        view.addSubview(imageView)
        view.addSubview(descriptionLabel)
        view.addSubview(titleLabel)

        setupLayout()
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            descriptionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            gotItButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 80),
            view.bottomAnchor.constraint(equalTo: gotItButton.bottomAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),

            titleLabel.widthAnchor.constraint(equalToConstant: 280),

            descriptionLabel.widthAnchor.constraint(equalToConstant: 280),

            imageView.heightAnchor.constraint(equalToConstant: 64),
            imageView.widthAnchor.constraint(equalToConstant: 128),

            gotItButton.widthAnchor.constraint(equalToConstant: 280),
        ])
    }

    override func mouseDown(with event: NSEvent) {}

    @objc func gotItAction(_ sender: Any) {
        delegate?.fireInfoViewControllerDidConfirm(self)
    }

}

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 320, height: 363)) {
    FireInfoViewController()
}
