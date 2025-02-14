//
//  PromptsCoordinator.swift
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

public extension Notification.Name {
    static let showPopoverPromptForDefaultBrowser = Notification.Name("com.duckduckgo.app.showPopoverPromptForDefaultBrowser")
    static let showPopoverPromptForDefaultBrowserAddressBar = Notification.Name("com.duckduckgo.app.showPopoverPromptForDefaultBrowserAddressBar")
    static let showBannerPromptForDefaultBrowser = Notification.Name("com.duckduckgo.app.showBannerPromptForDefaultBrowser")
}

enum PromptStyle {
    case popover(PromptContent)
    case banner(PromptContent)

    var title: String? {
        switch self {
        case let .popover(content):
            return content.title
        default:
            return nil
        }
    }

    var icon: NSImage {
        switch self {
        case let .popover(content):
            switch content {
            case .addToDockPrompt: return .attIconPopover
            default: return .addAsDefaultPopoverIcon
            }
        case let .banner(content):
            switch content {
            case .addToDockPrompt: return .attIconBanner
            default: return .greenShield
            }
        }
    }

    var message: String {
        switch self {
        case let .popover(content):
            switch content {
            case .addToDockPrompt:
                return "Get quick access to protected browsing when you add DuckDuckGo to your Dock."
            case .setAsDefaultPrompt:
                return "Make us your default browser so all site links open in DuckDuckGo"
            case .both:
                return "Make us your default browser so all site links open in DuckDuckGo, and add us to your Dock for quick access."
            }
        case let .banner(content):
            switch content {
            case .addToDockPrompt: return "Get quick access to protected browsing"
            default: return "Protect more of what you do online"
            }
        }
    }

    var primaryButtonTitle: String {
        switch self {
        case let .popover(content):
            switch content {
            case .addToDockPrompt: return "Add To Dock"
            default: return "Set As Default Browser"
            }
        case let .banner(content):
            switch content {
            case .addToDockPrompt: return "Add DuckDuckGo To Dock..."
            default: return "Set DuckDuckGo As Default Browser..."
            }
        }
    }

    var secondaryButtonTitle: String? {
        switch self {
        case .popover:
            return "Not Now"
        default:
            return nil
        }
    }
}

enum PromptContent {
    case both
    case setAsDefaultPrompt
    case addToDockPrompt

    var title: String {
        switch self {
        case .addToDockPrompt:
            return "Add DuckDuckGo to your Dock"
        default:
            return "Let DuckDuckGo protect more of what you do online"
        }
    }

    static func getStyle(isSparkle: Bool, isDefaultBrowser: Bool, isOnDock: Bool) -> PromptContent? {
        if isSparkle {
            if isDefaultBrowser && isOnDock {
                return nil
            } else if isDefaultBrowser && !isOnDock {
                return .addToDockPrompt
            } else if !isDefaultBrowser && isOnDock {
                return .setAsDefaultPrompt
            } else {
                return .both
            }
        } else {
            return isDefaultBrowser ? nil : .setAsDefaultPrompt
        }
    }
}

/// The `PromptsCoordinator` class is responsible for managing the display of prompts to the user in a macOS browser application.
///
/// This class serves as a centralized coordinator for handling different types of prompts, such as "Set As Default Browser" and "Add To The Dock". The decision on which prompt to display is based on a flag, which can be set to either show a popover or a banner.
///
/// The `PromptsCoordinator` class is designed to encapsulate the logic for determining which prompt to display, as well as the presentation of the prompt itself. This allows the rest of the application to interact with the `PromptsCoordinator` without needing to know the specific implementation details of each prompt type.
///
/// By using a coordinator pattern, the `PromptsCoordinator` class helps to maintain a separation of concerns and improve the overall organization and maintainability of the application's codebase. It also makes it easier to add or modify prompt types in the future, as the changes can be localized within the `PromptsCoordinator` class.
///
/// The `PromptsCoordinator` class should be responsible for the following tasks:
/// - Determining which prompt to display based on the provided flag
/// - Presenting the appropriate prompt (popover or banner) to the user
/// - Handling user interactions with the prompt (e.g., setting the browser as default, adding to the dock)
/// - Providing a consistent interface for other parts of the application to interact with the prompts
/// - Firing pixels related to the prompts
///
/// By encapsulating the prompt-related logic within the `PromptsCoordinator` class, the rest of the application can focus on its core functionality, while the `PromptsCoordinator` ensures that the prompts are displayed and handled correctly.
final class PromptsCoordinator {
    let dockCustomization: DockCustomization
    let defaultBrowserProvider: DefaultBrowserProvider
#if SPARKLE
    let isSparkleBuild: Bool = true
#else
    let isSparkleBuild: Bool = false
#endif

    init(dockCustomization: DockCustomization = DockCustomizer(),
         defaultBrowserProvider: DefaultBrowserProvider = SystemDefaultBrowserProvider()) {
        self.dockCustomization = dockCustomization
        self.defaultBrowserProvider = defaultBrowserProvider
    }

    var shouldShowPrompt: Bool {
        let wasOnboardingCompleted = false // TODO: Swap for real value
        return AppDelegate.twoDaysPassedSinceFirstLaunch && wasOnboardingCompleted
    }

    func getPopover() -> PopoverMessageViewController? {
        let isDefaultBrowser = defaultBrowserProvider.isDefault
        let isAddedToDock = dockCustomization.isAddedToDock
        guard let content = PromptContent.getStyle(isSparkle: isSparkleBuild, isDefaultBrowser: isDefaultBrowser, isOnDock: isAddedToDock) else {
            return nil
        }
        let style = PromptStyle.popover(content)

        return PopoverMessageViewController(title: style.title,
                                            message: style.message,
                                            image: style.icon,
                                            buttonText: style.primaryButtonTitle,
                                            buttonAction: { self.onSetAsDefaultBrowser() },
                                            secondaryButtonText: style.secondaryButtonTitle,
                                            secondaryButtonAction: { self.onPopoverDismissed() },
                                            shouldShowCloseButton: false,
                                            presentMultiline: true,
                                            autoDismissDuration: nil,
                                            alignment: .vertical)
    }

    func getBanner(closeAction: @escaping (() -> Void)) -> BannerMessageViewController? {
        let isDefaultBrowser = defaultBrowserProvider.isDefault
        let isAddedToDock = dockCustomization.isAddedToDock
        guard let content = PromptContent.getStyle(isSparkle: isSparkleBuild, isDefaultBrowser: isDefaultBrowser, isOnDock: isAddedToDock) else {
            return nil
        }
        let style = PromptStyle.banner(content)

        return BannerMessageViewController(message: style.message,
                                           image: style.icon,
                                           buttonText: style.primaryButtonTitle,
                                           buttonAction: { self.onSetAsDefaultBrowser() },
                                           closeAction: { closeAction() })
    }

    // MARK: - Private

    private func onSetAsDefaultBrowser() {
        if isSparkleBuild && !dockCustomization.isAddedToDock{
            dockCustomization.addToDock()
        }

        do {
            try defaultBrowserProvider.presentDefaultBrowserPrompt()
        } catch {
            defaultBrowserProvider.openSystemPreferences()
        }
    }

    private func onPopoverDismissed() {
        /// TODO: We need to do the following:
        /// - Fire a pixel with the dimissal
        /// - Save a flag in user defaults so we do not show the popover again
    }
}
