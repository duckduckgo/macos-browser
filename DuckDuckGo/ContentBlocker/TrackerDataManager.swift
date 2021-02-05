//
//  TrackerDataManager.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import TrackerRadarKit

class TrackerDataManager {

    struct Constants {
        static let embeddedDataSetETag = "7c0a71eb049748b86e8590353141a90f"
        static let embeddedDataSetSHA = "rIBc/qpKYsUxT6+oceMEnF/IUgBCz0tcWMOQWW/waac="
    }

    enum DataSet {

        case embedded
        case embeddedFallback
        case downloaded

    }

    static let shared = TrackerDataManager()

    private(set) var trackerData: TrackerData! {
        didSet {
            let encodedData = try? JSONEncoder().encode(trackerData)
            encodedTrackerData = String(data: encodedData!, encoding: .utf8)!
        }
    }

    private(set) var encodedTrackerData: String!
    private(set) var etag: String?

    init() {
        reload(etag: nil)
    }

    @discardableResult
    func reload(etag: String?) -> DataSet {
        let trackerData = try? JSONDecoder().decode(TrackerData.self, from: Self.loadEmbeddedAsData())
        self.trackerData = trackerData!
        self.etag = Constants.embeddedDataSetETag
        return .embedded
    }

    func findTracker(forUrl url: String) -> KnownTracker? {
        guard let host = URL(string: url)?.host else { return nil }
        for host in variations(of: host) {
            if let tracker = trackerData.trackers[host] {
                return tracker
            } else if let cname = trackerData.cnames?[host] {
                var tracker = trackerData.findTracker(byCname: cname)
                tracker = tracker?.copy(withNewDomain: cname)
                return tracker
            }
        }
        return nil
    }

    func findEntity(byName name: String) -> Entity? {
        return trackerData.entities[name]
    }

    func findEntity(forHost host: String) -> Entity? {
        for host in variations(of: host) {
            if let entityName = trackerData.domains[host] {
                return trackerData.entities[entityName]
            }
        }
        return nil
    }

    private func variations(of host: String) -> [String] {
        var parts = host.components(separatedBy: ".")
        var domains = [String]()
        while parts.count > 1 {
            let domain = parts.joined(separator: ".")
            domains.append(domain)
            parts.removeFirst()
        }
        return domains
    }

    static var embeddedUrl: URL {
        return Bundle.main.url(forResource: "trackerData", withExtension: "json")!
    }

    static func loadEmbeddedAsData() -> Data {
        let json = try? Data(contentsOf: embeddedUrl)
        return json!
    }

    static func loadEmbeddedAsString() -> String {
        let json = try? String(contentsOf: embeddedUrl, encoding: .utf8)
        return json!
    }

}
