//
//  PhishingDetectionManager.swift
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

import Foundation
import PhishingDetection

public protocol PhishingDetectionManaging {
    func isMalicious(url: URL) async -> Bool
    func loadDataAsync()
}

public final class PhishingDetectionManager: PhishingDetectionManaging {
    static let shared = PhishingDetectionManager()

    private let phishingDetectionService = PhishingDetectionService()
    private let phishingDetectionDataActivities = PhishingDetectionDataActivities()

    private init() {
        loadDataAsync()
    }

    public func isMalicious(url: URL) async -> Bool {
        return await phishingDetectionService.isMalicious(url: url)
    }

    public func loadDataAsync() {
        Task {
            phishingDetectionService.loadData()
            await phishingDetectionDataActivities.run()
        }
    }

}
