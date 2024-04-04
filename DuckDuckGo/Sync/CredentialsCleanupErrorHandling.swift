//
//  CredentialsCleanupErrorHandling.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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
import Common
import Persistence
import PixelKit

public class CredentialsCleanupErrorHandling: EventMapping<CredentialsCleanupError> {

    public init() {
        super.init { event, _, _, _ in
            if event.cleanupError is CredentialsCleanupCancelledError {
                PixelKit.fire(DebugEvent(GeneralPixel.credentialsCleanupAttemptedWhileSyncWasEnabled))
            } else {
                let processedErrors = CoreDataErrorsParser.parse(error: event.cleanupError as NSError)
                let params = processedErrors.errorPixelParameters

                PixelKit.fire(DebugEvent(GeneralPixel.credentialsDatabaseCleanupFailed, error: event.cleanupError), withAdditionalParameters: params)
            }
        }
    }

    override init(mapping: @escaping EventMapping<CredentialsCleanupError>.Mapping) {
        fatalError("Use init()")
    }
}
