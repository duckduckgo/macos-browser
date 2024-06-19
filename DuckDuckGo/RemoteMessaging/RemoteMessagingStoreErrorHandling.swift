//
//  RemoteMessagingStoreErrorHandling.swift
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

import Common
import Foundation
import RemoteMessaging

public class RemoteMessagingStoreErrorHandling: EventMapping<RemoteMessagingStoreError> {

    public init() {
        super.init { event, error, _, _ in
            switch event {
            case .saveConfigFailed:
                break
//                Pixel.fire(pixel: .dbRemoteMessagingSaveConfigError, error: error)
            case .invalidateConfigFailed:
                break
//                Pixel.fire(pixel: .dbRemoteMessagingInvalidateConfigError, error: error)
            case .updateMessageShownFailed:
                break
//                Pixel.fire(pixel: .dbRemoteMessagingUpdateMessageShownError, error: error)
            case .saveMessageFailed:
                break
//                Pixel.fire(pixel: .dbRemoteMessagingSaveMessageError, error: error)
            case .updateMessageStatusFailed:
                break
//                Pixel.fire(pixel: .dbRemoteMessagingUpdateMessageStatusError, error: error)
            case .deleteScheduledMessageFailed:
                break
//                Pixel.fire(pixel: .dbRemoteMessagingDeleteScheduledMessageError, error: error)
            }
        }
    }

    override init(mapping: @escaping EventMapping<RemoteMessagingStoreError>.Mapping) {
        fatalError("Use init()")
    }
}
