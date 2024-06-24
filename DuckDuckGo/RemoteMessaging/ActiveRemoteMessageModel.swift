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
import Foundation
import RemoteMessaging

final class ActiveRemoteMessageModel: ObservableObject {

    @Published var remoteMessage: RemoteMessageModel?
    let fetchMessage: () -> RemoteMessageModel?
    let onDismiss: (RemoteMessageModel) -> Void

    convenience init(client: RemoteMessagingClient) {
        self.init { [weak client] in
            client?.store?.fetchScheduledRemoteMessage()
        } onDismiss: { [weak client] message in
            client?.store?.dismissRemoteMessage(withId: message.id)
        }
    }

    init(fetchMessage: @escaping () -> RemoteMessageModel?, onDismiss: @escaping (RemoteMessageModel) -> Void) {
        self.fetchMessage = fetchMessage
        self.onDismiss = onDismiss
        updateRemoteMessage()

        messagesDidChangeCancellable = NotificationCenter.default
            .publisher(for: RemoteMessagingStore.Notifications.remoteMessagesDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateRemoteMessage()
            }
    }

    func dismissRemoteMessage() {
        if let remoteMessage {
            onDismiss(remoteMessage)
            self.remoteMessage = nil
        }
    }

    private func updateRemoteMessage() {
        remoteMessage = fetchMessage()
    }

    private var messagesDidChangeCancellable: AnyCancellable?
}
