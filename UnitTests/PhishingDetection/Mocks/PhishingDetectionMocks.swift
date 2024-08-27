//
//  PhishingDetectionMocks.swift
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
import XCTest
import Combine
import PhishingDetection
@testable import DuckDuckGo_Privacy_Browser

final class MockPhishingDetectionDataStore: PhishingDetectionDataFileStoring {
    var currentRevision: Int = 0
    var didWriteData: Bool = false
    var didLoadData: Bool = false
    var filterSet = Set<Filter>()
    var hashPrefixes = Set<String>()

    func writeData() {
        didWriteData = true
    }

    func loadData() async {
        didLoadData = true
    }
}

final class MockPhishingDataActivitites: PhishingDetectionDataActivityHandling {
    var started: Bool = false
    var stopped: Bool = false

    func start() {
        started = true
    }

    func stop() {
        stopped = true
    }
}

final class MockPhishingDetection: PhishingDetecting {
    func isMalicious(url: URL) async -> Bool {
        return url.absoluteString.contains("malicious")
    }
}

final class MockPhishingSiteDetector: PhishingSiteDetecting {
    var isMalicious: Bool = false

    init(isMalicious: Bool) {
        self.isMalicious = isMalicious
    }

    func checkIsMaliciousIfEnabled(url: URL) async -> Bool {
        return isMalicious
    }
}
