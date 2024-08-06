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
import Persistence
import PixelKit
import RemoteMessaging

public class RemoteMessagingStoreErrorHandling: EventMapping<RemoteMessagingStoreError> {

    public init() {
        super.init { event, error, _, _ in

            let params: [String: String]? = {
                guard let nsError = error as? NSError else {
                    return nil
                }
                let processedErrors = CoreDataErrorsParser.parse(error: nsError)
                return processedErrors.errorPixelParameters
            }()

            let pixel: GeneralPixel = {
                switch event {
                case .saveConfigFailed:
                    return .remoteMessagingSaveConfigError
                case .updateMessageShownFailed:
                    return .remoteMessagingUpdateMessageShownError
                case .updateMessageStatusFailed:
                    return .remoteMessagingUpdateMessageStatusError
                }
            }()

            PixelKit.fire(pixel, withAdditionalParameters: params, withError: error)
        }
    }

    override init(mapping: @escaping EventMapping<RemoteMessagingStoreError>.Mapping) {
        fatalError("Use init()")
    }
}
