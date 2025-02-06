//
//  MismatchCalculator.swift
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
import BrowserServicesKit
import os.log
import Common

enum MismatchValues: Int {
    case parentSiteHasMoreMatches
    case childSiteHasMoreMatches
    case noMismatch

    static func calculate(parent: Int, child: Int) -> MismatchValues {
        if parent == child {
            return .noMismatch
        } else if parent > child {
            return .parentSiteHasMoreMatches
        } else {
            return .childSiteHasMoreMatches
        }
    }
}

protocol MismatchCalculator {
    init(database: DataBrokerProtectionRepository, pixelHandler: EventMapping<DataBrokerProtectionPixels>)
    func calculateMismatches()
}

struct DefaultMismatchCalculator: MismatchCalculator {
    let database: DataBrokerProtectionRepository
    let pixelHandler: EventMapping<DataBrokerProtectionPixels>

    func calculateMismatches() {
        let brokerProfileQueryData: [BrokerProfileQueryData]
        do {
            brokerProfileQueryData = try database.fetchAllBrokerProfileQueryData()
        } catch {
            Logger.dataBrokerProtection.error("MismatchCalculatorUseCase error: calculateMismatches, error: \(error.localizedDescription, privacy: .public)")
            return
        }

        let parentBrokerProfileQueryData = brokerProfileQueryData.filter { $0.dataBroker.parent == nil }

        for parent in parentBrokerProfileQueryData {
            guard let parentMatches = parent.scanJobData.historyEvents.matchesForLastEvent() else { continue }
            let children = brokerProfileQueryData.filter {
                $0.dataBroker.parent == parent.dataBroker.url &&
                $0.profileQuery.id == parent.profileQuery.id
            }

            for child in children {
                guard let childMatches = child.scanJobData.historyEvents.matchesForLastEvent() else { continue }
                let mismatchValue = MismatchValues.calculate(parent: parentMatches, child: childMatches)

                pixelHandler.fire(
                    .parentChildMatches(
                        parent: parent.dataBroker.name,
                        child: child.dataBroker.name,
                        value: mismatchValue.rawValue
                    )
                )
            }
        }
    }
}

extension Array where Element == HistoryEvent {

    func matchesForLastEvent() -> Int? {
        guard let lastEvent = self.sorted(by: { $0.date < $1.date }).last else { return nil }

        switch lastEvent.type {
        case .noMatchFound:
            return 0
        case .matchesFound(let count):
            return count
        default:
            return nil
        }
    }
}
