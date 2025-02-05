//
//  DataBroker.swift
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
import os.log

struct DataBrokerScheduleConfig: Codable {
    let retryError: Int
    let confirmOptOutScan: Int
    let maintenanceScan: Int
    let maxAttempts: Int

    // Used when scheduling the subsequent opt-out attempt following a successful opt-out request submission
    // This value should be less than `confirmOptOutScan` to ensure the next attempt occurs before
    // the confirmation scan.
    var hoursUntilNextOptOutAttempt: Int {
        maintenanceScan
    }
}

extension Int {
    var hoursToSeconds: TimeInterval {
        return TimeInterval(self * 3600)
    }
}

struct MirrorSite: Codable, Sendable {
    let name: String
    let url: String
    let addedAt: Date
    let removedAt: Date?

    enum CodingKeys: CodingKey {
        case name
        case url
        case addedAt
        case removedAt
    }

    init(name: String, url: String, addedAt: Date, removedAt: Date? = nil) {
        self.name = name
        self.url = url
        self.addedAt = addedAt
        self.removedAt = removedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)

        // The older versions of the JSON file did not have a URL property.
        // When decoding those cases, we fallback to its name, since the name was the URL.
        do {
            url = try container.decode(String.self, forKey: .url)
        } catch {
            url = name
        }

        addedAt = try container.decode(Date.self, forKey: .addedAt)
        removedAt = try? container.decode(Date.self, forKey: .removedAt)

    }

    func wasRemoved(since: Date = Date()) -> Bool {
        guard let removedAt = self.removedAt else {
            return false
        }

        return removedAt < since
    }
}

extension MirrorSite {

    typealias ScannedBroker = DBPUIScanProgress.ScannedBroker

    func scannedBroker(withStatus status: ScannedBroker.Status) -> ScannedBroker {
        ScannedBroker(name: name, url: url, status: status)
    }

    /// Determines whether a mirror site should be included in scan result calculations based on the provided date.
    ///
    /// - Parameter date: The date for which to check if the mirror site should be included. Defaults to the current date.
    /// - Returns: A Boolean value indicating whether the mirror site should be included.
    ///   - `true`: If the profile was added before the given date and has not been removed, or if it was removed but the provided date is between the `addedAt` and `removedAt` timestamps.
    ///   - `false`: If the profile was either added after the given date or has been removed before the given date.
    func shouldWeIncludeMirrorSite(for date: Date = Date()) -> Bool {
        if let removedAt = self.removedAt {
            return self.addedAt < date && date < removedAt
        } else {
            return self.addedAt < date
        }
    }
}

public enum DataBrokerHierarchy: Int {
    case parent = 1
    case child = 0
}

public struct DataBroker: Codable, Sendable {
    let id: Int64?
    let name: String
    let url: String
    let steps: [Step]
    let version: String
    let schedulingConfig: DataBrokerScheduleConfig
    let parent: String?
    let mirrorSites: [MirrorSite]
    let optOutUrl: String

    var isFakeBroker: Bool {
        name.contains("fake") // A future improvement will be to add a property in the JSON file.
    }

    enum CodingKeys: CodingKey {
        case name
        case url
        case steps
        case version
        case schedulingConfig
        case parent
        case mirrorSites
        case optOutUrl
    }

    init(id: Int64? = nil,
         name: String,
         url: String,
         steps: [Step],
         version: String,
         schedulingConfig: DataBrokerScheduleConfig,
         parent: String? = nil,
         mirrorSites: [MirrorSite] = [MirrorSite](),
         optOutUrl: String
    ) {
        self.id = id
        self.name = name

        if url.isEmpty {
            self.url = name
        } else {
            self.url = url
        }

        self.steps = steps
        self.version = version
        self.schedulingConfig = schedulingConfig
        self.parent = parent
        self.mirrorSites = mirrorSites
        self.optOutUrl = optOutUrl
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)

        // The older versions of the JSON file did not have a URL property.
        // When decoding those cases, we fallback to its name, since the name was the URL.
        do {
            url = try container.decode(String.self, forKey: .url)
        } catch {
            url = name
        }

        version = try container.decode(String.self, forKey: .version)
        steps = try container.decode([Step].self, forKey: .steps)
        // Hotfix for https://app.asana.com/0/1203581873609357/1208895331283089/f
        do {
            schedulingConfig = try container.decode(DataBrokerScheduleConfig.self, forKey: .schedulingConfig)
        } catch {
            schedulingConfig = .init(retryError: 48, confirmOptOutScan: 72, maintenanceScan: 120, maxAttempts: -1)
        }
        parent = try? container.decode(String.self, forKey: .parent)

        do {
            let mirrorSitesDecoding = try container.decode([MirrorSite].self, forKey: .mirrorSites)
            mirrorSites = mirrorSitesDecoding
        } catch {
            mirrorSites = [MirrorSite]()
        }

        optOutUrl = (try? container.decode(String.self, forKey: .optOutUrl)) ?? ""

        id = nil
    }

    func scanStep() throws -> Step {
        guard let scanStep = steps.first(where: { $0.type == .scan }) else {
            assertionFailure("Broker is missing the scan step.")
            throw DataBrokerProtectionError.unrecoverableError
        }

        return scanStep
    }

    func optOutStep() -> Step? {
        guard let optOutStep = steps.first(where: { $0.type == .optOut }) else {
            return nil
        }

        return optOutStep
    }

    func performsOptOutWithinParent() -> Bool {
        guard let optOutStep = optOutStep(), let optOutType = optOutStep.optOutType else { return false }

        return optOutType == .parentSiteOptOut
    }

    static func initFromResource(_ url: URL) throws -> DataBroker {
        do {
            let data = try Data(contentsOf: url)
            let jsonDecoder = JSONDecoder()
            jsonDecoder.dateDecodingStrategy = .millisecondsSince1970
            let broker = try jsonDecoder.decode(DataBroker.self, from: data)
            return broker
        } catch {
            Logger.dataBrokerProtection.error("DataBroker error: initFromResource, error: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}

extension DataBroker: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    public static func == (lhs: DataBroker, rhs: DataBroker) -> Bool {
        return lhs.name == rhs.name
    }
}

extension DataBroker {

    var type: DataBrokerHierarchy {
        parent == nil ? .parent : .child
    }
}
