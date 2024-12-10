//
//  FreemiumDBPExperimentPixel.swift
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

import PixelKit
import Common

public class FreemiumDBPExperimentPixelHandler: EventMapping<FreemiumDBPExperimentPixel> {

    public init() {
        super.init { event, _, params, _ in
            switch event {
            case .subscription:
                PixelKit.fire(event, frequency: .uniqueByName, withAdditionalParameters: params)
            default:
                PixelKit.fire(event, frequency: .uniqueByName)
            }

        }
    }

    override init(mapping: @escaping EventMapping<FreemiumDBPExperimentPixel>.Mapping) {
        fatalError("Use init()")
    }
}

public enum FreemiumDBPExperimentPixel: PixelKitEventV2 {

    // Before the first scan
    case newTabScanImpression
    case newTabScanClick
    case newTabScanDismiss
    // When receiving results
    case newTabResultsImpression
    case newTabResultsClick
    case newTabResultsDismiss
    // When receiving no results
    case newTabNoResultsImpression
    case newTabNoResultsClick
    case newTabNoResultsDismiss
    // Overflow menu
    case overFlowScan
    case overFlowResults
    // System notification
    case firstScanCompleteNotificationSent
    case firstScanCompleteNotificationClicked
    // Subscription
    case subscription

    public var name: String {
        switch self {
        case .newTabScanImpression:
            return "dbp-free_newtab_scan_impression_u"
        case .newTabScanClick:
            return "dbp-free_newtab_scan_click_u"
        case .newTabScanDismiss:
            return "dbp-free_newtab_scan_dismiss_u"
        case .newTabResultsImpression:
            return "dbp-free_newtab_results_impression_u"
        case .newTabResultsClick:
            return "dbp-free_newtab_results_click_u"
        case .newTabResultsDismiss:
            return "dbp-free_newtab_results_dismiss_u"
        case .newTabNoResultsImpression:
            return "dbp-free_newtab_no-results_impression_u"
        case .newTabNoResultsClick:
            return "dbp-free_newtab_no-results_click_u"
        case .newTabNoResultsDismiss:
            return "dbp-free_newtab_no-results_dismiss_u"
        case .overFlowScan:
            return "dbp-free_overflow_scan_u"
        case .overFlowResults:
            return "dbp-free_overflow_results_u"
        case .firstScanCompleteNotificationSent:
            return "dbp-free_notification_sent_first_scan_complete_u"
        case .firstScanCompleteNotificationClicked:
            return "dbp-free_notification_opened_first_scan_complete_u"
        case .subscription:
            return "dbp-free_subscription_u"
        }
    }

    public var parameters: [String: String]? {
        return nil
    }

    public var error: (any Error)? {
        nil
    }
}
