//
//  TabBarRemoteMessageViewModel.swift
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

import Combine
import RemoteMessaging

struct TabBarRemoteMessage {
    static let tabBarPermanentSurveyRemoteMessageId = "macos_permanent_survey_tab_bar"

    let buttonTitle: String
    let popupTitle: String
    let popupSubtitle: String
    let surveyURL: URL
}

final class TabBarRemoteMessageViewModel: ObservableObject {

    private let activeRemoteMessageModel: ActiveRemoteMessageModel
    private var cancellable: AnyCancellable?

    @Published var remoteMessage: TabBarRemoteMessage?

    init(activeRemoteMessageModel: ActiveRemoteMessageModel) {
        self.activeRemoteMessageModel = activeRemoteMessageModel

        cancellable = activeRemoteMessageModel.$remoteMessage
            .sink(receiveValue: { model in
                guard let model = model else {
                    self.remoteMessage = nil
                    return
                }

                if model.shouldShowTabBarRemoteMessage, let tabBarRemoteMessage = model.mapToTabBarRemoteMessage() {
                    self.remoteMessage = tabBarRemoteMessage
                }
        })
    }

    func onDismiss() {
        Task { await activeRemoteMessageModel.dismissRemoteMessage(with: .close) }
    }

    /// When the user hovers the Tab Bar Remote Message and we show the popup, there is where when we mark
    /// that the user really saw the message.
    func onUserHovered() {
        Task { await activeRemoteMessageModel.markRemoteMessageAsShown() }
    }

    func onOpenSurvey() {
        Task { await activeRemoteMessageModel.dismissRemoteMessage(with: .primaryAction) }
    }
}

private extension RemoteMessageModel {

    var shouldShowTabBarRemoteMessage: Bool {
        guard let modelType = content else { return false }

        return modelType.isSupported && isForTabBar
    }

    func mapToTabBarRemoteMessage() -> TabBarRemoteMessage? {
        guard let modelType = content else { return nil }

        switch modelType {
        case .bigSingleAction(let titleText,
                              let descriptionText,
                              _,
                              let primaryActionText,
                              let primaryAction):

            if case .survey(let value) = primaryAction, let surveyURL = URL(string: value) {
                return .init(buttonTitle: titleText,
                             popupTitle: primaryActionText,
                             popupSubtitle: descriptionText,
                             surveyURL: surveyURL)
            } else {
                return nil
            }
        default: return nil
        }
    }
}
