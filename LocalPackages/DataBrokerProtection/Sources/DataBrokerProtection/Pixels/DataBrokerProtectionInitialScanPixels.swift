//
//  DataBrokerProtectionInitialScanPixels.swift
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

enum InitialScanState {
    case webSiteLoading
    case other
}

final class DataBrokerProtectionInitialScanPixels {

    private let handler: EventMapping<DataBrokerProtectionPixels>
    private let brokerURL: String

    var startSiteLoadingTime: Date?
    var finishedSiteLoadingTime: Date?
    var startPostLoadingTime: Date?
    var finishedPostLoadingTime: Date?

    init(handler: EventMapping<DataBrokerProtectionPixels>, 
         brokerURL: String,
         startSiteLoadingTime: Date? = nil,
         finishedSiteLoadingTime: Date? = nil, 
         startPostLoadingTime: Date? = nil,
         finishedPostLoadingTime: Date? = nil) {
        self.handler = handler
        self.brokerURL = brokerURL
        self.startSiteLoadingTime = startSiteLoadingTime
        self.finishedSiteLoadingTime = finishedSiteLoadingTime
        self.startPostLoadingTime = startPostLoadingTime
        self.finishedPostLoadingTime = finishedPostLoadingTime
    }

    func fireInitialScanSiteLoadDurationPixel(hasError: Bool) {
        if let startSiteLoadingTime = self.startSiteLoadingTime {
            let durationinMs = (Date().timeIntervalSince(startSiteLoadingTime) * 1000).rounded(.towardZero)
            handler.fire(.initialScanSiteLoadDuration(duration: durationinMs, hasError: hasError, brokerURL: brokerURL))
        }
    }

    func fireInitialScanPostLoadingDurationPixel(hasError:Bool) {
        if let startPostLoadingTime = self.startPostLoadingTime {
            let durationinMs = (Date().timeIntervalSince(startPostLoadingTime) * 1000).rounded(.towardZero)
            handler.fire(.initialScanSiteLoadDuration(duration: durationinMs, hasError: hasError, brokerURL: brokerURL))
        }
    }
}
