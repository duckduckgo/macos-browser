//
//  DataBrokerProtectionWebUIPixels.swift
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
import Common
import BrowserServicesKit
import PixelKit

final class DataBrokerProtectionWebUIPixels {

    enum PixelType {
        case loading
        case success
    }

    let pixelHandler: EventMapping<DataBrokerProtectionPixels>
    private var wasHTTPErrorPixelFired = false

    init(pixelHandler: EventMapping<DataBrokerProtectionPixels>) {
        self.pixelHandler = pixelHandler
    }

    func firePixel(for error: Error) {
        if wasHTTPErrorPixelFired {
            wasHTTPErrorPixelFired = false // We reset the flag
            return
        }

        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain {
            let statusCode = nsError.code
            if statusCode >= 400 && statusCode < 600 {
                pixelHandler.fire(.webUILoadingFailed(errorCategory: "httpError-\(statusCode)"))
                wasHTTPErrorPixelFired = true
            } else {
                pixelHandler.fire(.webUILoadingFailed(errorCategory: "other-\(nsError.code)"))
            }
        } else {
            pixelHandler.fire(.webUILoadingFailed(errorCategory: "other-\(nsError.code)"))
        }
    }

    func firePixel(for selectedURL: DataBrokerProtectionWebUIURLType, type: PixelType) {
        let environment = selectedURL == .custom ? "staging" : "production"

        switch type {
        case .loading:
            pixelHandler.fire(.webUILoadingStarted(environment: environment))
        case .success:
            pixelHandler.fire(.webUILoadingSuccess(environment: environment))
        }
    }
}
