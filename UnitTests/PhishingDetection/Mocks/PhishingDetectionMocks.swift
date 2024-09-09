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

class MockDataProvider: PhishingDetectionDataProviding {
    var embeddedFilterSet: Set<Filter> = []
    var embeddedHashPrefixes: Set<String> = []
    var embeddedRevision: Int = 0
    var didLoadFilterSet: Bool = false
    var didLoadHashPrefixes: Bool = false

    func loadEmbeddedFilterSet() -> Set<Filter> {
        didLoadFilterSet = true
        return embeddedFilterSet
    }

    func loadEmbeddedHashPrefixes() -> Set<String> {
        didLoadHashPrefixes = true
        return embeddedHashPrefixes
    }
}

class MockFileStorageManager: FileStorageManager {
    private var storage: [String: Data] = [:]
    var didWriteToDisk: Bool = false
    var didReadFromDisk: Bool = false

    func write(data: Data, to filename: String) {
        didWriteToDisk = true
        storage[filename] = data
    }

    func read(from filename: String) -> Data? {
        didReadFromDisk = true
        return storage[filename]
    }
}

final class MockPhishingDataActivitites: PhishingDetectionDataActivityHandling {
    var started: Bool = false
    var stopped: Bool = true

    func start() {
        started = true
        stopped = false
    }

    func stop() {
        stopped = true
        started = false
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
