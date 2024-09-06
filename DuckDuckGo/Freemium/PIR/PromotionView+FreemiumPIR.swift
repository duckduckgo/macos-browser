//
//  PromotionView+FreemiumPIR.swift
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

extension PromotionViewModel {
    static func freemiumPIRPromotion(proceedAction: @escaping () -> Void,
                                     closeAction: @escaping () -> Void) -> PromotionViewModel {

        let subtitle = UserText.homePagePromotionFreemiumPIRSubtitle
        let actionButtonText = UserText.homePagePromotionFreemiumPIRButtonTitle

        return PromotionViewModel(image: .radarCheck,
                                  subtitle: subtitle,
                                  proceedButtonText: actionButtonText,
                                  proceedAction: proceedAction,
                                  closeAction: closeAction)
    }

    static func freemiumPIRPromotionScanEngagementResults(resultCount: Int,
                                                                brokerCount: Int,
                                                                proceedAction: @escaping () -> Void,
                                                                closeAction: @escaping () -> Void) -> PromotionViewModel {

        var title = UserText.homePagePromotionFreemiumPIRPostScanEngagementResultsTitle
        var subtitle = ""

        switch (resultCount, brokerCount) {
        case (1, _):
            subtitle = UserText.homePagePromotionFreemiumPIRPostScanEngagementResultSingleMatchSubtitle
        case (let resultCount, 1):
            subtitle = UserText.homePagePromotionFreemiumPIRPostScanEngagementResultSingleBrokerSubtitle(resultCount: resultCount)
        default:
            subtitle = UserText.homePagePromotionFreemiumPIRPostScanEngagementResultPluralSubtitle(resultCount: resultCount,
                                                                                                       brokerCount: brokerCount)
        }
        
        let actionButtonText = UserText.homePagePromotionFreemiumPIRPostScanEngagementButtonTitle

        return PromotionViewModel(image: .radarCheck,
                                  title: title,
                                  subtitle: subtitle,
                                  proceedButtonText: actionButtonText,
                                  proceedAction: proceedAction,
                                  closeAction: closeAction)
    }

    static func freemiumPIRPromotionScanEngagementNoResults(proceedAction: @escaping () -> Void,
                                                            closeAction: @escaping () -> Void) -> PromotionViewModel {

        let title = UserText.homePagePromotionFreemiumPIRPostScanEngagementNoResultsTitle
        let subtitle = UserText.homePagePromotionFreemiumPIRPostScanEngagementNoResultsSubtitle
        let actionButtonText = UserText.homePagePromotionFreemiumPIRPostScanEngagementButtonTitle

        return PromotionViewModel(image: .radarCheck,
                                  title: title,
                                  subtitle: subtitle,
                                  proceedButtonText: actionButtonText,
                                  proceedAction: proceedAction,
                                  closeAction: closeAction)
    }
}
