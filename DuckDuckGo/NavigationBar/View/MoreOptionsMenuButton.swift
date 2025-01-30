//
//  MoreOptionsMenuButton.swift
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

import Cocoa
import Combine

final class MoreOptionsMenuButton: MouseOverButton {

    private static let notificationSize: CGFloat = 6
    private static let notificationOffset: CGFloat = 3

#if SPARKLE
    private var updateController: UpdateControllerProtocol?
    private var dockCustomization: DockCustomization?
#endif

    private var notificationLayer: CALayer?
    private var cancellable: AnyCancellable?

    var notificationColor: NSColor = .updateIndicator {
        didSet {
            updateNotificationLayer()
        }
    }

    var isNotificationVisible: Bool = false {
        didSet {
            updateNotificationVisibility()
#if SPARKLE
            needsDisplay = isNotificationVisible != oldValue
#endif
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

#if SPARKLE
        if NSApp.runType != .uiTests {
            updateController = Application.appDelegate.updateController
            dockCustomization = Application.appDelegate.dockCustomization
        }
        subscribeToUpdateInfo()
#endif
    }

    override func updateLayer() {
        super.updateLayer()
        setupNotificationLayerIfNeeded()
    }

    private func subscribeToUpdateInfo() {
#if SPARKLE
        guard let updateController, let dockCustomization else { return }
        cancellable = Publishers.CombineLatest3(updateController.hasPendingUpdatePublisher, updateController.notificationDotPublisher, dockCustomization.shouldShowNotificationPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasPendingUpdate, needsNotificationDot, shouldNotificationForAddToDock in
                self?.isNotificationVisible = hasPendingUpdate && needsNotificationDot || shouldNotificationForAddToDock
            }
#endif
    }

    private func setupNotificationLayerIfNeeded() {
        guard notificationLayer == nil, let layer = self.layer else { return }

        let notificationLayer = CALayer()
        notificationLayer.backgroundColor = notificationColor.cgColor
        layoutNotification(notificationLayer: notificationLayer)
        notificationLayer.isHidden = !isNotificationVisible
        layer.addSublayer(notificationLayer)
        self.notificationLayer = notificationLayer
    }

    private func updateNotificationLayer() {
        notificationLayer?.backgroundColor = notificationColor.cgColor
    }

    private func updateNotificationVisibility() {
        notificationLayer?.isHidden = !isNotificationVisible
    }

    override func layout() {
        super.layout()
        layoutNotification(notificationLayer: notificationLayer)
    }

    private func layoutNotification(notificationLayer: CALayer?) {
        // Position the dot notification indicator to upper right corner of the button
        notificationLayer?.frame = CGRect(
            x: self.bounds.width - MoreOptionsMenuButton.notificationSize - MoreOptionsMenuButton.notificationOffset,
            y: MoreOptionsMenuButton.notificationOffset,
            width: MoreOptionsMenuButton.notificationSize,
            height: MoreOptionsMenuButton.notificationSize
        )
        notificationLayer?.cornerRadius = MoreOptionsMenuButton.notificationSize / 2
    }

}
