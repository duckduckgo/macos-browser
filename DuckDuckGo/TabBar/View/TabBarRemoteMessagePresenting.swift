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

/// A protocol that defines the requirements for presenting tab bar remote messages in the macOS browser tab bar..
///
/// This protocol is designed for any class that needs to manage the display of remote messages in the tab bar.
/// It provides properties for managing the view model, popover, and UI components related to the remote message presentation.
///
/// Properties:
/// - `tabBarRemoteMessageViewModel`: The view model responsible for managing the state and data of the tab bar remote message.
/// - `rightSideStackView`: The stack view that contains the UI elements on the right side of the tab bar.
/// - `tabBarRemoteMessagePopover`: An optional popover that displays additional information related to the remote message.
/// - `tabBarRemoteMessagePopoverHoverTimer`: An optional timer that controls the display of the popover based on user interaction.
/// - `feedbackBarButtonHostingController`: An optional hosting controller that manages the view for the feedback button associated with the remote message.
/// - `tabBarRemoteMessageCancellable`: An optional cancellable for the Combine publisher that listens for changes in the remote message state.
protocol TabBarRemoteMessagePresenting: AnyObject {
    var tabBarRemoteMessageViewModel: TabBarRemoteMessageViewModel { get }
    var rightSideStackView: NSStackView! { get }
    var tabBarRemoteMessagePopover: NSPopover? { get set }
    var tabBarRemoteMessagePopoverHoverTimer: Timer? { get set }
    var feedbackBarButtonHostingController: NSHostingController<TabBarRemoteMessageView>? { get set }
    var tabBarRemoteMessageCancellable: AnyCancellable? { get set }
}

extension TabBarRemoteMessagePresenting {

    /// Adds a listener for changes in the remote message state.
    ///
    /// This method subscribes to the `remoteMessage` publisher of the `tabBarRemoteMessageViewModel`.
    /// When a new remote message is received, it displays the message if the feedback button is not already shown.
    /// If the remote message is nil, it removes the feedback button if it is currently displayed.
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

    /// Displays the tab bar remote message in the UI.
    ///
    /// This method creates a `TabBarRemoteMessageView` with the provided remote message and sets up
    /// actions for closing the message, tapping on it, and handling hover events.
    /// The view is then inserted into the `rightSideStackView`.
    ///
    /// - Parameter tabBarRemotMessage: The remote message to be displayed.
    private func showTabBarRemoteMessage(_ tabBarRemotMessage: TabBarRemoteMessage) {
        let feedbackButtonView = TabBarRemoteMessageView(
            model: tabBarRemotMessage,
            onClose: { [weak self] in
                guard let self = self else { return }

                self.tabBarRemoteMessageViewModel.onMessageDismissed()
                self.removeFeedbackButton()
            },
            onTap: { [weak self] surveyURL in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    WindowControllersManager.shared.showTab(with: .contentFromURL(surveyURL, source: .appOpenUrl))
                }
                self.tabBarRemoteMessageViewModel.onSurveyOpened()
                self.removeFeedbackButton()
            },
            onHover: { [weak self] in
                guard let self = self else { return }
                self.startTabBarRemotMessageTimer(message: tabBarRemotMessage)
            },
            onHoverEnd: { [weak self] in
                guard let self = self else { return }
                self.dismissTabBarRemoteMessagePopover()
            },
            onAppear: { [weak self] in
                guard let self = self else { return }
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

    /// Starts a timer to show the tab bar remote message popover after a delay.
    ///
    /// This method invalidates any existing timer and creates a new timer that will trigger the display
    /// of the popover after a specified time interval.
    ///
    /// - Parameter message: The remote message associated with the popover
    private func startTabBarRemotMessageTimer(message: TabBarRemoteMessage) {
        tabBarRemoteMessagePopoverHoverTimer?.invalidate()
        tabBarRemoteMessagePopoverHoverTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.showTabBarRemotePopup(message)
        }
    }

    /// Dismisses the tab bar remote message popover.
    ///
    /// This method invalidates the hover timer and closes the popover if it is currently displayed.
    private func dismissTabBarRemoteMessagePopover() {
        tabBarRemoteMessagePopoverHoverTimer?.invalidate()
        tabBarRemoteMessagePopover?.close()
    }

    /// Shows the tab bar remote message popover.
    ///
    /// This method displays the popover containing the remote message. If the popover has not been created yet,
    /// it initializes and configures it before displaying.
    ///
    /// - Parameter message: The remote message to be displayed in the popover.
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

    /// Configures the popover with the specified remote message.
    ///
    /// This method sets the properties of the popover, including its size and content view controller,
    /// which displays the remote message.
    ///
    /// - Parameter message: The remote message to configure the popover with.
    private func configurePopover(with message: TabBarRemoteMessage) {
        guard let popover = tabBarRemoteMessagePopover else { return }

        let contentView = TabBarRemoteMessagePopoverContent(model: message)
        popover.animates = true
        popover.behavior = .semitransient
        popover.contentSize = NSHostingView(rootView: contentView).fittingSize
        let controller = NSViewController()
        controller.view = NSHostingView(rootView: contentView)
        popover.contentViewController = controller
    }

    /// Removes the feedback button from the UI.
    ///
    /// This method removes the feedback button's view from the `rightSideStackView` and cleans up
    /// the associated hosting controller.
    private func removeFeedbackButton() {
        guard let hostingController = feedbackBarButtonHostingController else { return }

        rightSideStackView.removeArrangedSubview(hostingController.view)
        hostingController.view.removeFromSuperview()
        hostingController.removeFromParent()
        feedbackBarButtonHostingController = nil
    }

}
