//
//  DataBrokerProtectionBackendServicePixels.swift
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

import PixelKit
import Common
import BrowserServicesKit

public enum BackendServiceCallSite: String {
    case extractEmailLink
    case getEmail
    case submitCaptchaInformationRequest
    case submitCaptchaToBeResolvedRequest
}

protocol DataBrokerProtectionBackendServicePixels {
    func fireGenerateEmailHTTPError(statusCode: Int)
    func fireEmptyAccessToken(callSite: BackendServiceCallSite)
}

final class DefaultDataBrokerProtectionBackendServicePixels: DataBrokerProtectionBackendServicePixels {
    private let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private let settings: DataBrokerProtectionSettings

    init(pixelHandler: EventMapping<DataBrokerProtectionPixels> = DataBrokerProtectionPixelsHandler(),
         settings: DataBrokerProtectionSettings = DataBrokerProtectionSettings()) {
        self.pixelHandler = pixelHandler
        self.settings = settings
    }

    func fireGenerateEmailHTTPError(statusCode: Int) {
        let environment = settings.selectedEnvironment.rawValue

        pixelHandler.fire(.generateEmailHTTPErrorDaily(statusCode: statusCode,
                                                       environment: environment,
                                                       wasOnWaitlist: false))
    }

    func fireEmptyAccessToken(callSite: BackendServiceCallSite) {
        let environment = settings.selectedEnvironment.rawValue

        pixelHandler.fire(.emptyAccessTokenDaily(environment: environment,
                                                 wasOnWaitlist: false,
                                                 callSite: callSite))
    }
}
