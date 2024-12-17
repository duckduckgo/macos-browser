//
//  TabBarRemoteMessagePresenting.swift
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

protocol TabBarRemoteMessagePresenting: AnyObject {
    var tabBarRemoteMessageViewModel: TabBarRemoteMessageViewModel { get }
    var rightSideStackView: NSStackView! { get }
    var tabBarRemoteMessagePopover: NSPopover? { get set }
    var tabBarRemoteMessagePopoverHoverTimer: Timer? { get set }
    var feedbackBarButtonHostingController: NSHostingController<TabBarRemoteMessageView>? { get set }
    var tabBarRemoteMessageCancellable: AnyCancellable? { get set }
}

extension TabBarRemoteMessagePresenting {

    func addTabBarRemoteMessageListener() {
        tabBarRemoteMessageCancellable = tabBarRemoteMessageViewModel.$remoteMessage
            .sink(receiveValue: { tabBarRemoteMessage in
                if let tabBarRemoteMessage = tabBarRemoteMessage {
                    if self.feedbackBarButtonHostingController == nil {
                        self.showTabBarRemoteMessage(tabBarRemoteMessage)
                    }
                } else {
                    if self.feedbackBarButtonHostingController != nil {
                        self.removeFeedbackButton()
                    }
                }
            })
    }

    private func showTabBarRemoteMessage(_ tabBarRemotMessage: TabBarRemoteMessage) {
        let feedbackButtonView = TabBarRemoteMessageView(
            model: tabBarRemotMessage,
            onClose: {
                self.tabBarRemoteMessageViewModel.onMessageDismissed()
                self.removeFeedbackButton()
            },
            onTap: { surveyURL in
                DispatchQueue.main.async {
                    WindowControllersManager.shared.showTab(with: .contentFromURL(surveyURL, source: .appOpenUrl))
                }
                self.tabBarRemoteMessageViewModel.onSurveyOpened()
                self.removeFeedbackButton()
            },
            onHover: {
                self.startTabBarRemotMessageTimer(message: tabBarRemotMessage)
            },
            onHoverEnd: {
                self.dismissTabBarRemoteMessagePopover()
            },
            onAppear: {
                self.tabBarRemoteMessageViewModel.markTabBarRemoteMessageAsShown()
            }
        )
        feedbackBarButtonHostingController = NSHostingController(rootView: feedbackButtonView)
        guard let feedbackBarButtonHostingController else { return }

        feedbackBarButtonHostingController.view.translatesAutoresizingMaskIntoConstraints = false

        // Insert the hosting controller's view into the stack view just before the fire button
        let index = max(0, rightSideStackView.arrangedSubviews.count - 1)
        rightSideStackView.insertArrangedSubview(feedbackBarButtonHostingController.view, at: index)

        NSLayoutConstraint.activate([
            feedbackBarButtonHostingController.view.centerYAnchor.constraint(equalTo: rightSideStackView.centerYAnchor)
        ])
    }

    private func startTabBarRemotMessageTimer(message: TabBarRemoteMessage) {
        tabBarRemoteMessagePopoverHoverTimer?.invalidate()
        tabBarRemoteMessagePopoverHoverTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            self.showTabBarRemotePopup(message)
        }
    }

    private func dismissTabBarRemoteMessagePopover() {
        tabBarRemoteMessagePopoverHoverTimer?.invalidate()
        tabBarRemoteMessagePopover?.close()
    }

    private func showTabBarRemotePopup(_ message: TabBarRemoteMessage) {
        guard let tabBarButtonRemoteMessageView = feedbackBarButtonHostingController?.view else {
            return
        }

        if let popover = tabBarRemoteMessagePopover {
            popover.show(positionedBelow: tabBarButtonRemoteMessageView.bounds, in: tabBarButtonRemoteMessageView)
        } else {
            tabBarRemoteMessagePopover = NSPopover()
            configurePopover(with: message)

            tabBarRemoteMessagePopover?.show(positionedBelow: tabBarButtonRemoteMessageView.bounds, in: tabBarButtonRemoteMessageView)
        }
    }

    private func configurePopover(with message: TabBarRemoteMessage) {
        guard let popover = tabBarRemoteMessagePopover else { return }

        popover.animates = true
        popover.behavior = .semitransient
        popover.contentSize = NSSize(width: TabBarRemoteMessagePopoverContent.Constants.width,
                                     height: TabBarRemoteMessagePopoverContent.Constants.height)

        let controller = NSViewController()
        controller.view = NSHostingView(rootView: TabBarRemoteMessagePopoverContent(model: message))
        popover.contentViewController = controller
    }

    private func removeFeedbackButton() {
        guard let hostingController = feedbackBarButtonHostingController else { return }

        rightSideStackView.removeArrangedSubview(hostingController.view)
        hostingController.view.removeFromSuperview()
        hostingController.removeFromParent()
        feedbackBarButtonHostingController = nil
    }

}
