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
    @Published var isViewOnScreen: Bool = false

    /**
     * A block that returns a remote messaging store, if it exists.
     *
     * Store is initialized lazily, after the model that uses it. The store may also
     * remain nil as long as RMF is disabled by a feature flag. The use of a closure
     * ensures that a non-nil store will be retrieved when requested.
     */
    let store: () -> RemoteMessagingStoring?

    convenience init(remoteMessagingClient: RemoteMessagingClient) {
        self.init(
            remoteMessagingStore: remoteMessagingClient.store,
            remoteMessagingAvailabilityProvider: remoteMessagingClient.remoteMessagingAvailabilityProvider
        )
    }

    /**
     * We allow for nil availability provider in order to support running in unit tests.
     */
    init(
        remoteMessagingStore: @escaping @autoclosure () -> RemoteMessagingStoring?,
        remoteMessagingAvailabilityProvider: RemoteMessagingAvailabilityProviding?
    ) {
        self.store = remoteMessagingStore

        let messagesDidChangePublisher = NotificationCenter.default.publisher(for: RemoteMessagingStore.Notifications.remoteMessagesDidChange)
            .asVoid()
            .eraseToAnyPublisher()

        let isRemoteMessagingAvailablePublisher: AnyPublisher<Bool, Never> = {
            guard let isRemoteMessagingAvailablePublisher = remoteMessagingAvailabilityProvider?.isRemoteMessagingAvailablePublisher else {
                return Empty<Bool, Never>().eraseToAnyPublisher()
            }
            return isRemoteMessagingAvailablePublisher
        }()

        let featureFlagDidChangePublisher = isRemoteMessagingAvailablePublisher
            .removeDuplicates()
            .asVoid()
            .eraseToAnyPublisher()

        Publishers.Merge(messagesDidChangePublisher, featureFlagDidChangePublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateRemoteMessage()
            }
            .store(in: &cancellables)

        let remoteMessagePublisher = $remoteMessage.compactMap({ $0 }).asVoid()
        let isViewOnScreenPublisher = $isViewOnScreen.removeDuplicates().filter({ $0 }).asVoid()
        Publishers.Merge(remoteMessagePublisher, isViewOnScreenPublisher)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else {
                    return
                }
                if isViewOnScreen {
                    markRemoteMessageAsShown()
                }
            }
            .store(in: &cancellables)

        updateRemoteMessage()
    }

    func dismissRemoteMessage(with action: RemoteMessageViewModel.ButtonAction?) {
        guard let remoteMessage else {
            return
        }

        store()?.dismissRemoteMessage(withID: remoteMessage.id)
        self.remoteMessage = nil

        let pixel: GeneralPixel? = {
            guard remoteMessage.isMetricsEnabled else {
                return nil
            }
            switch action {
            case .close:
                return GeneralPixel.remoteMessageDismissed
            case .action:
                return GeneralPixel.remoteMessageActionClicked
            case .primaryAction:
                return GeneralPixel.remoteMessagePrimaryActionClicked
            case .secondaryAction:
                return GeneralPixel.remoteMessageSecondaryActionClicked
            default:
                return nil
            }
        }()

        if let pixel {
            PixelKit.fire(pixel, withAdditionalParameters: ["message": remoteMessage.id])
        }
    }

    func markRemoteMessageAsShown() {
        guard let remoteMessage, let store = store() else {
            return
        }
        os_log("Remote message shown: %s", log: .remoteMessaging, type: .info, remoteMessage.id)
        if remoteMessage.isMetricsEnabled {
            PixelKit.fire(GeneralPixel.remoteMessageShown, withAdditionalParameters: ["message": remoteMessage.id])
        }
        if !store.hasShownRemoteMessage(withID: remoteMessage.id) {
            os_log("Remote message shown for first time: %s", log: .remoteMessaging, type: .info, remoteMessage.id)
            if remoteMessage.isMetricsEnabled {
                PixelKit.fire(GeneralPixel.remoteMessageShownUnique, withAdditionalParameters: ["message": remoteMessage.id])
            }
            store.updateRemoteMessage(withID: remoteMessage.id, asShown: true)
        }
    }

    var shouldShowRemoteMessage: Bool {
        remoteMessage?.content?.isSupported == true
    }

    private func updateRemoteMessage() {
        remoteMessage = store()?.fetchScheduledRemoteMessage()
    }

    private var cancellables = Set<AnyCancellable>()
}

extension RemoteMessageModelType {

    var isSupported: Bool {
        switch self {
        case .promoSingleAction:
            return false
        default:
            return true
        }
    }
}
