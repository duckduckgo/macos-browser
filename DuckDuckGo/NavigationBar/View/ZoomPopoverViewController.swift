//
//  ZoomPopoverViewController.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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
import Combine

protocol ZoomPopoverViewControllerDelegate: AnyObject {
    func isMouseOverDidChange()
    func rescheduleCloseTimerIfNeeded()
}

final class ZoomPopoverViewController: NSViewController {

    private let viewModel: ZoomPopoverViewModel
    weak var delegate: ZoomPopoverViewControllerDelegate?

    private var cancellables = Set<AnyCancellable>()

    private let mouseOverView = MouseOverView()
    private let zoomLevelLabel = NSTextField(labelWithString: "")
    private lazy var resetButton = MouseOverButton(title: UserText.resetZoom, target: self, action: #selector(resetZoom))
    private lazy var zoomOutButton = MouseOverButton(image: NSImage(systemSymbolName: "minus", accessibilityDescription: UserText.mainMenuViewZoomOut)!,
                                                     target: self,
                                                     action: #selector(zoomOut))
    private lazy var zoomInButton = MouseOverButton(image: NSImage(systemSymbolName: "plus", accessibilityDescription: UserText.mainMenuViewZoomIn)!,
                                                    target: self,
                                                    action: #selector(zoomIn))

    init(viewModel: ZoomPopoverViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()

        mouseOverView.delegate = self
        mouseOverView.translatesAutoresizingMaskIntoConstraints = false

        zoomLevelLabel.translatesAutoresizingMaskIntoConstraints = false
        zoomLevelLabel.isEditable = false
        zoomLevelLabel.isSelectable = false
        zoomLevelLabel.font = .systemFont(ofSize: 13, weight: .bold)
        zoomLevelLabel.alignment = .center

        for button in [resetButton, zoomOutButton, zoomInButton] {
            button.font = .systemFont(ofSize: 13)
            button.bezelStyle = .shadowlessSquare
            button.cornerRadius = 6
            button.normalTintColor = .controlTextColor
            button.backgroundColor = .blackWhite10
            button.mouseOverColor = .buttonMouseOver
            button.mouseDownColor = .buttonMouseDown
            button.imagePosition = (button === resetButton) ? .noImage : .imageOnly
            button.translatesAutoresizingMaskIntoConstraints = false
        }

        resetButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        resetButton.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        resetButton.horizontalPadding = 12 * 2

        resetButton.toolTip = UserText.resetZoom
        zoomOutButton.toolTip = UserText.mainMenuViewZoomOut
        zoomInButton.toolTip = UserText.mainMenuViewZoomIn

        view.addSubview(mouseOverView)
        view.addSubview(zoomLevelLabel)
        view.addSubview(resetButton)
        view.addSubview(zoomOutButton)
        view.addSubview(zoomInButton)

        setupLayout()
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            mouseOverView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            mouseOverView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
            mouseOverView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            mouseOverView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),

            // Zoom Level Label
            zoomLevelLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            zoomLevelLabel.widthAnchor.constraint(equalToConstant: 69),
            zoomLevelLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            // Reset Button
            resetButton.leadingAnchor.constraint(equalTo: zoomLevelLabel.trailingAnchor, constant: 8),
            resetButton.heightAnchor.constraint(equalToConstant: 28),
            resetButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 59), // Allow width to adjust
            resetButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            // Zoom Out Button
            zoomOutButton.leadingAnchor.constraint(equalTo: resetButton.trailingAnchor, constant: 8),
            zoomOutButton.widthAnchor.constraint(equalToConstant: 37),
            zoomOutButton.heightAnchor.constraint(equalToConstant: 28),
            zoomOutButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            // Zoom In Button
            zoomInButton.leadingAnchor.constraint(equalTo: zoomOutButton.trailingAnchor, constant: 1),
            zoomInButton.widthAnchor.constraint(equalToConstant: 37),
            zoomInButton.heightAnchor.constraint(equalToConstant: 28),
            zoomInButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            view.trailingAnchor.constraint(equalTo: zoomInButton.trailingAnchor, constant: 16),

            view.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    override func viewDidLoad() {
        setupBindings()
    }

    private func setupBindings() {
        // Bind the zoom level to the label
        viewModel.$zoomLevel
            .map(\.displayString)
            .assign(to: \.stringValue, on: zoomLevelLabel)
            .store(in: &cancellables)
    }

    @objc private func resetZoom() {
        viewModel.reset()
    }

    @objc private func zoomOut() {
        viewModel.zoomOut()
    }

    @objc private func zoomIn() {
        viewModel.zoomIn()
    }

}

extension ZoomPopoverViewController: MouseOverViewDelegate {

    func mouseOverView(_ mouseOverView: MouseOverView, isMouseOver: Bool) {
        delegate?.isMouseOverDidChange()
    }

}
