//
//  ActiveRemoteMessageModel.swift
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
import Common
import Foundation
import PixelKit
import RemoteMessaging

final class ActiveRemoteMessageModel: ObservableObject {

    @Published var remoteMessage: RemoteMessageModel?
    let remoteMessagingClient: RemoteMessagingClient

    init(client: RemoteMessagingClient) {
        self.remoteMessagingClient = client

        updateRemoteMessage()

        messagesDidChangeCancellable = NotificationCenter.default
            .publisher(for: RemoteMessagingStore.Notifications.remoteMessagesDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateRemoteMessage()
            }
    }

    func dismissRemoteMessage(with action: HomeMessageViewModel.ButtonAction?) {
        guard let remoteMessage else {
            return
        }

        remoteMessagingClient.store?.dismissRemoteMessage(withId: remoteMessage.id)
        self.remoteMessage = nil

        let pixelParameters = ["message": remoteMessage.id]
        switch action {
        case .close:
            PixelKit.fire(GeneralPixel.remoteMessageDismissed, withAdditionalParameters: pixelParameters)
        case .action:
            PixelKit.fire(GeneralPixel.remoteMessageActionClicked, withAdditionalParameters: pixelParameters)
        case .primaryAction:
            PixelKit.fire(GeneralPixel.remoteMessagePrimaryActionClicked, withAdditionalParameters: pixelParameters)
        case .secondaryAction:
            PixelKit.fire(GeneralPixel.remoteMessageSecondaryActionClicked, withAdditionalParameters: pixelParameters)
        default:
            break
        }
    }

    func markRemoteMessageAsShown() {
        guard let remoteMessage, let store = remoteMessagingClient.store else {
            return
        }
        os_log("Remote message shown: %s", log: .remoteMessaging, type: .info, remoteMessage.id)
        PixelKit.fire(GeneralPixel.remoteMessageShown, withAdditionalParameters: ["message": remoteMessage.id])
        if !store.hasShownRemoteMessage(withId: remoteMessage.id) {
            os_log("Remote message shown for first time: %s", log: .remoteMessaging, type: .info, remoteMessage.id)
            PixelKit.fire(GeneralPixel.remoteMessageShownUnique, withAdditionalParameters: ["mesage": remoteMessage.id])
            store.updateRemoteMessage(withId: remoteMessage.id, asShown: true)
        }
    }

    private func updateRemoteMessage() {
        remoteMessage = remoteMessagingClient.store?.fetchScheduledRemoteMessage()
    }

    private var messagesDidChangeCancellable: AnyCancellable?
}
