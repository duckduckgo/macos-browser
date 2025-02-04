//
//  CapturingNewTabPageRecentActivityProvider.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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
import Common
import NewTabPage

final class CapturingNewTabPageRecentActivityProvider: NewTabPageRecentActivityProviding {
    func refreshActivity() -> [NewTabPageDataModel.DomainActivity] {
        refreshActivityCallCount += 1
        return refreshActivityReturnValue
    }

    var activityPublisher: AnyPublisher<[NewTabPageDataModel.DomainActivity], Never> {
        $activity.dropFirst().eraseToAnyPublisher()
    }

    @Published var activity: [NewTabPageDataModel.DomainActivity] = []

    var refreshActivityCallCount = 0
    var refreshActivityReturnValue: [NewTabPageDataModel.DomainActivity] = []
}
