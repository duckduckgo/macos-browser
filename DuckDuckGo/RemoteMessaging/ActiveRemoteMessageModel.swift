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

import BrowserServicesKit
import Combine
import Common
import Foundation
import PixelKit
import RemoteMessaging

/**
 * This is used to feed a remote message to the home page view.
 *
 * We keep a single instance of `ActiveRemoteMessageModel` in `AppDelegate`
 * because interacting with a remote message on any new tab page in any of the
 * application windows should dismiss the message on all new tab pages in all windows.
 * Secondly, we don't want multiple fetches and data refreshes in response to data
 * changed notifications.
 */
final class ActiveRemoteMessageModel: ObservableObject {

    @Published var remoteMessage: RemoteMessageModel?

    /**
     * A block that returns a remote messaging store, if it exists.
     *
     * Store is initialized lazily, after the model that uses it. The store may also
     * remain nil as long as RMF is disabled by a feature flag. The use of a closure
     * ensures that a non-nil store will be retrieved when requested.
     */
    let store: () -> RemoteMessagingStoring?
    let remoteMessagingAvailabilityProvider: RemoteMessagingAvailabilityProviding

    convenience init(remoteMessagingClient: RemoteMessagingClient) {
        self.init(
            remoteMessagingStore: remoteMessagingClient.store,
            remoteMessagingAvailabilityProvider: remoteMessagingClient.remoteMessagingAvailabilityProvider
        )
    }

    init(
        remoteMessagingStore: @escaping @autoclosure () -> RemoteMessagingStoring?,
        remoteMessagingAvailabilityProvider: RemoteMessagingAvailabilityProviding
    ) {
        self.store = remoteMessagingStore
        self.remoteMessagingAvailabilityProvider = remoteMessagingAvailabilityProvider

        updateRemoteMessage()

        let messagesDidChangePublisher = NotificationCenter.default.publisher(for: RemoteMessagingStore.Notifications.remoteMessagesDidChange)
            .asVoid()
            .eraseToAnyPublisher()

        let featureFlagDidChangePublisher = remoteMessagingAvailabilityProvider.isRemoteMessagingAvailablePublisher
            .removeDuplicates()
            .asVoid()
            .eraseToAnyPublisher()

        Publishers.Merge(messagesDidChangePublisher, featureFlagDidChangePublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateRemoteMessage()
            }
            .store(in: &cancellables)

    }

    func dismissRemoteMessage(with action: RemoteMessageViewModel.ButtonAction?) {
        guard let remoteMessage else {
            return
        }

        store()?.dismissRemoteMessage(withID: remoteMessage.id)
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
        guard let remoteMessage, let store = store() else {
            return
        }
        os_log("Remote message shown: %s", log: .remoteMessaging, type: .info, remoteMessage.id)
        PixelKit.fire(GeneralPixel.remoteMessageShown, withAdditionalParameters: ["message": remoteMessage.id])
        if !store.hasShownRemoteMessage(withID: remoteMessage.id) {
            os_log("Remote message shown for first time: %s", log: .remoteMessaging, type: .info, remoteMessage.id)
            PixelKit.fire(GeneralPixel.remoteMessageShownUnique, withAdditionalParameters: ["mesage": remoteMessage.id])
            store.updateRemoteMessage(withID: remoteMessage.id, asShown: true)
        }
    }

    private func updateRemoteMessage() {
        remoteMessage = store()?.fetchScheduledRemoteMessage()
    }

    private var cancellables = Set<AnyCancellable>()
}
