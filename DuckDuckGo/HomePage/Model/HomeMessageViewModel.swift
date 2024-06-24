//
//  HomeMessageViewModel.swift
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

import Foundation
import BrowserServicesKit
import RemoteMessaging

struct HomeMessageViewModel {
    enum ButtonAction {
        case close
        case action(isShare: Bool) // a generic action that is specific to the type of message
        case primaryAction(isShare: Bool)
        case secondaryAction(isShare: Bool)
    }

    let messageId: String
    let modelType: RemoteMessageModelType

    var image: String? {
        modelType.image
    }

    var title: String {
        modelType.title
    }

    var subtitle: String {
        modelType.subtitle
    }

    var buttons: [HomeMessageButtonViewModel] {
        switch modelType {
        case .small:
            return []
        case .medium:
            return []
        case .bigSingleAction(_, _, _, let primaryActionText, let primaryAction):
            return [
                HomeMessageButtonViewModel(title: primaryActionText,
                                           actionStyle: primaryAction.actionStyle(),
                                           action: mapActionToViewModel(remoteAction: primaryAction, buttonAction:
                                                .primaryAction(isShare: primaryAction.isShare), onDidClose: onDidClose))
            ]
        case .bigTwoAction(_, _, _, let primaryActionText, let primaryAction, let secondaryActionText, let secondaryAction):
            return [
                HomeMessageButtonViewModel(title: secondaryActionText,
                                           actionStyle: secondaryAction.actionStyle(isSecondaryAction: true),
                                           action: mapActionToViewModel(remoteAction: secondaryAction, buttonAction:
                                                .secondaryAction(isShare: secondaryAction.isShare), onDidClose: onDidClose)),

                HomeMessageButtonViewModel(title: primaryActionText,
                                           actionStyle: primaryAction.actionStyle(),
                                           action: mapActionToViewModel(remoteAction: primaryAction, buttonAction:
                                           .primaryAction(isShare: primaryAction.isShare), onDidClose: onDidClose))
            ]
        case .promoSingleAction(_, _, _, let actionText, let action):
            return [
                HomeMessageButtonViewModel(title: actionText,
                                           actionStyle: action.actionStyle(),
                                           action: mapActionToViewModel(remoteAction: action, buttonAction:
                                                .action(isShare: action.isShare), onDidClose: onDidClose))]
        }
    }

    let onDidClose: (ButtonAction?) -> Void
    let openURLHandler: (URL) -> Void

    func mapActionToViewModel(remoteAction: RemoteAction,
                              buttonAction: HomeMessageViewModel.ButtonAction,
                              onDidClose: @escaping (HomeMessageViewModel.ButtonAction?) -> Void) -> () -> Void {

        switch remoteAction {
        case .share:
            return {
                onDidClose(buttonAction)
            }
        case .url(let value):
            return {
                if let url = URL.makeURL(from: value) {
                    openURLHandler(url)
                }
                onDidClose(buttonAction)
            }
        case .survey(let value):
            return {
                if let url = URL.makeURL(from: value) {
                    openURLHandler(url)
                }
                onDidClose(buttonAction)
            }
        case .appStore:
            return {
                let url = URL(string: "https://apps.apple.com/app/duckduckgo-privacy-browser/id663592361")!
                openURLHandler(url)
                onDidClose(buttonAction)
            }
        case .dismiss:
            return {
                onDidClose(buttonAction)
            }
        }
    }
}

struct HomeMessageButtonViewModel {
    enum ActionStyle {
        case `default`
        case share(value: String, title: String?)
        case cancel
    }

    let title: String
    var actionStyle: ActionStyle = .default
    let action: () -> Void

}

extension RemoteAction {

    func actionStyle(isSecondaryAction: Bool = false) -> HomeMessageButtonViewModel.ActionStyle {
        switch self {
        case .share(let value, let title):
            return .share(value: value, title: title)

        case .appStore, .url, .survey:
            if isSecondaryAction {
                return .cancel
            }
            return .default

        case .dismiss:
            return .cancel
        }
    }

    var isShare: Bool {
        if case .share = self.actionStyle() {
            return true
        }
        return false
    }
}

private extension RemoteMessageModelType {
    var image: String? {
        switch self {
        case .small:
            return nil
        case .medium(_, _, let placeholder):
            return placeholder.rawValue
        case .bigSingleAction(_, _, let placeholder, _, _):
            return placeholder.rawValue
        case .bigTwoAction(_, _, let placeholder, _, _, _, _):
            return placeholder.rawValue
        case .promoSingleAction(_, _, let placeholder, _, _):
            return placeholder.rawValue
        }
    }

    var title: String {
        switch self {
        case .small(let titleText, _):
            return titleText
        case .medium(let titleText, _, _):
            return titleText
        case .bigSingleAction(let titleText, _, _, _, _):
            return titleText
        case .bigTwoAction(let titleText, _, _, _, _, _, _):
            return titleText
        case .promoSingleAction(let titleText, _, _, _, _):
            return titleText
        }
    }

    var subtitle: String {
        let subtitle = {
            switch self {
            case .small(_, let descriptionText):
                return descriptionText
            case .medium(_, let descriptionText, _):
                return descriptionText
            case .bigSingleAction(_, let descriptionText, _, _, _):
                return descriptionText
            case .bigTwoAction(_, let descriptionText, _, _, _, _, _):
                return descriptionText
            case .promoSingleAction(_, let descriptionText, _, _, _):
                return descriptionText
            }
        }()
        return subtitle
            .replacingOccurrences(of: "<b>", with: "**")
            .replacingOccurrences(of: "</b>", with: "**")
    }
}
