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

final class TabBarRemoteMessageViewModel: ObservableObject {

    private let tabBarRemoteActiveMessage: TabBarRemoteMessageProviding
    private var cancellable: AnyCancellable?

    @Published var remoteMessage: TabBarRemoteMessage?

    init(activeRemoteMessageModel: TabBarRemoteMessageProviding, isFireWindow: Bool) {
        self.tabBarRemoteActiveMessage = activeRemoteMessageModel

        cancellable = tabBarRemoteActiveMessage.remoteMessagePublisher
            .sink(receiveValue: { model in
                guard !isFireWindow else { return }

                guard let model = model else {
                    self.remoteMessage = nil
                    return
                }

                if model.shouldShowTabBarRemoteMessage, let tabBarRemoteMessage = model.mapToTabBarRemoteMessage() {
                    self.remoteMessage = tabBarRemoteMessage
                }
        })
    }

    func onSurveyOpened() {
        Task { await tabBarRemoteActiveMessage.onSurveyOpened() }
    }

    func onMessageDismissed() {
        Task { await tabBarRemoteActiveMessage.onMessageDismissed() }
    }

    func markTabBarRemoteMessageAsShown() {
        Task { await tabBarRemoteActiveMessage.markRemoteMessageAsShown() }
    }
}

private extension RemoteMessageModel {

    var shouldShowTabBarRemoteMessage: Bool {
        guard let modelType = content else { return false }

        return modelType.isSupported
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
