//
//  PrivacyStatsTrackerDataProvider.swift
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
import NewTabPage
import TrackerRadarKit

final class PrivacyStatsTrackerDataProvider: PrivacyStatsTrackerDataProviding {
    var trackerData: TrackerData {
        trackerDataManager.trackerData
    }
    let trackerDataUpdatesPublisher: AnyPublisher<Void, Never>

    init(contentBlocking: ContentBlockingProtocol) {
        trackerDataManager = contentBlocking.trackerDataManager
        trackerDataUpdatesPublisher = contentBlocking.contentBlockingAssetsPublisher.asVoid().eraseToAnyPublisher()
    }

    private let trackerDataManager: TrackerDataManager
}

#if DEBUG
extension ContentBlockingMock: PrivacyStatsTrackerDataProviding {
    var trackerData: TrackerData {
        trackerDataManager.trackerData
    }

    var trackerDataUpdatesPublisher: AnyPublisher<Void, Never> {
        contentBlockingAssetsPublisher.asVoid().eraseToAnyPublisher()
    }
}
#endif
