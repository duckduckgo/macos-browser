//
//  MaliciousSiteProtectionMocks.swift
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

import Combine
import Foundation
import MaliciousSiteProtection
import XCTest

@testable import DuckDuckGo_Privacy_Browser

class MockMaliciousSiteDataProvider: MaliciousSiteProtection.EmbeddedDataProviding {

    var embeddedFilterSet: Set<Filter> = []
    var embeddedHashPrefixes: Set<String> = []
    var embeddedRevision: Int = 0
    var didLoadFilterSet: Bool = false
    var didLoadHashPrefixes: Bool = false

    public func revision(for detectionKind: MaliciousSiteProtection.DataManager.StoredDataType) -> Int {
        embeddedRevision
    }

    public func url(for detectionKind: MaliciousSiteProtection.DataManager.StoredDataType) -> URL {
        URL.empty
    }

    public func hash(for detectionKind: MaliciousSiteProtection.DataManager.StoredDataType) -> String {
        ""
    }

    func data(withContentsOf url: URL) throws -> Data {
        if url.lastPathComponent.lowercased().contains("filter") {
            self.didLoadFilterSet = true
            return try JSONEncoder().encode(embeddedFilterSet)
        } else {
            self.didLoadHashPrefixes = true
            return try JSONEncoder().encode(embeddedHashPrefixes)
        }
    }
}

class MockMaliciousSiteFileStore: MaliciousSiteProtection.FileStoring {
    private var storage: [String: Data] = [:]
    var didWriteToDisk: Bool = false
    var didReadFromDisk: Bool = false

    func write(data: Data, to filename: String) -> Bool {
        didWriteToDisk = true
        storage[filename] = data
        return true
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

final class MockMaliciousSiteDetector: MaliciousSiteProtection.MaliciousSiteDetecting {

    var isMalicious: (URL) -> MaliciousSiteProtection.ThreatKind? = { url in
        url.absoluteString.contains("malicious") ? .phishing : nil
    }

    init(isMalicious: ((URL) -> MaliciousSiteProtection.ThreatKind?)? = nil) {
        if let isMalicious {
            self.isMalicious = isMalicious
        }
    }

    func evaluate(_ url: URL) async -> MaliciousSiteProtection.ThreatKind? {
        return isMalicious(url)
    }
}
