//
//  RemoteMessageViewModel.swift
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

struct RemoteMessageViewModel {
    enum ButtonAction {
        case close
        case action // a generic action that is specific to the type of message
        case primaryAction
        case secondaryAction
    }

    let messageId: String
    let modelType: RemoteMessageModelType

    var image: ImageResource? {
        modelType.image
    }

    var title: String {
        modelType.title
    }

    var subtitle: String {
        modelType.subtitle
    }

    var buttons: [RemoteMessageButtonViewModel] {
        switch modelType {
        case .small, .medium, .promoSingleAction:
            return []
        case .bigSingleAction(_, _, _, let primaryActionText, let primaryAction):
            return [
                RemoteMessageButtonViewModel(title: primaryActionText,
                                           actionStyle: primaryAction.actionStyle(),
                                           action: mapActionToViewModel(remoteAction: primaryAction, buttonAction:
                                                .primaryAction, onDidClose: onDidClose))
            ]
        case .bigTwoAction(_, _, _, let primaryActionText, let primaryAction, let secondaryActionText, let secondaryAction):
            return [
                RemoteMessageButtonViewModel(title: secondaryActionText,
                                           actionStyle: secondaryAction.actionStyle(isSecondaryAction: true),
                                           action: mapActionToViewModel(remoteAction: secondaryAction, buttonAction:
                                                .secondaryAction, onDidClose: onDidClose)),

                RemoteMessageButtonViewModel(title: primaryActionText,
                                           actionStyle: primaryAction.actionStyle(),
                                           action: mapActionToViewModel(remoteAction: primaryAction, buttonAction:
                                                .primaryAction, onDidClose: onDidClose))
            ]
        }
    }

    let onDidClose: (ButtonAction?) async -> Void
    let onDidAppear: () -> Void
    let onDidDisappear: () -> Void
    let openURLHandler: (URL) -> Void

    func mapActionToViewModel(remoteAction: RemoteAction,
                              buttonAction: RemoteMessageViewModel.ButtonAction,
                              onDidClose: @escaping (RemoteMessageViewModel.ButtonAction?) async -> Void) -> () async -> Void {

        switch remoteAction {
        case .url(let value), .share(let value, _), .survey(let value):
            return { @MainActor in
                if let url = URL.makeURL(from: value) {
                    openURLHandler(url)
                }
                await onDidClose(buttonAction)
            }
        case .appStore:
            return { @MainActor in
                openURLHandler(.appStore)
                await onDidClose(buttonAction)
            }
        case .dismiss:
            return { @MainActor in
                await onDidClose(buttonAction)
            }
        }
    }
}

struct RemoteMessageButtonViewModel {
    enum ActionStyle: Equatable {
        case `default`
        case cancel
    }

    let title: String
    var actionStyle: ActionStyle = .default
    let action: () async -> Void
}

extension RemoteAction {

    func actionStyle(isSecondaryAction: Bool = false) -> RemoteMessageButtonViewModel.ActionStyle {
        switch self {
        case .appStore, .url, .survey, .share:
            if isSecondaryAction {
                return .cancel
            }
            return .default

        case .dismiss:
            return .cancel
        }
    }
}

private extension RemoteMessageModelType {

    var image: ImageResource? {
        switch self {
        case .small:
            return nil
        case .medium(_, _, let placeholder), .bigSingleAction(_, _, let placeholder, _, _), .bigTwoAction(_, _, let placeholder, _, _, _, _):
            switch placeholder {
            case .announce:
                return .remoteMessageAnnouncement
            case .ddgAnnounce:
                return .remoteMessageDDGAnnouncement
            case .criticalUpdate:
                return .remoteMessageCriticalAppUpdate
            case .appUpdate:
                return .remoteMessageAppUpdate
            case .privacyShield:
                return .remoteMessagePrivacyShield
            case .macComputer, .newForMacAndWindows:
                return nil
            }
        case .promoSingleAction:
            assertionFailure("promoSingleAction is not supported on macOS")
            return nil
        }
    }

    var title: String {
        switch self {
        case .small(let titleText, _),
                .medium(let titleText, _, _),
                .bigSingleAction(let titleText, _, _, _, _),
                .bigTwoAction(let titleText, _, _, _, _, _, _):

            return titleText

        case .promoSingleAction(let titleText, _, _, _, _):
            assertionFailure("promoSingleAction is not supported on macOS")
            return titleText
        }
    }

    var subtitle: String {
        let subtitle = {
            switch self {
            case .small(_, let descriptionText),
                    .medium(_, let descriptionText, _),
                    .bigSingleAction(_, let descriptionText, _, _, _),
                    .bigTwoAction(_, let descriptionText, _, _, _, _, _):

                return descriptionText

            case .promoSingleAction(_, let descriptionText, _, _, _):
                assertionFailure("promoSingleAction is not supported on macOS")
                return descriptionText
            }
        }()
        return subtitle
            .replacingOccurrences(of: "<b>", with: "**")
            .replacingOccurrences(of: "</b>", with: "**")
    }
}
