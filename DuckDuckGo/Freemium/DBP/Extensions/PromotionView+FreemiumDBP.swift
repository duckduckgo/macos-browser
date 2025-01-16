//
//  PromotionView+FreemiumDBP.swift
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
    static func freemiumDBPPromotion(proceedAction: @escaping () async -> Void,
                                     closeAction: @escaping () -> Void) -> PromotionViewModel {

        let title = UserText.homePagePromotionFreemiumDBPTitle
        var description = UserText.homePagePromotionFreemiumDBPDescription

        if #available(macOS 12.0, *) {
            description = UserText.homePagePromotionFreemiumDBPDescriptionMarkdown
        }

        let actionButtonText = UserText.homePagePromotionFreemiumDBPButtonTitle

        return PromotionViewModel(image: .informationRemover128,
                                  title: title,
                                  description: description,
                                  proceedButtonText: actionButtonText,
                                  proceedAction: proceedAction,
                                  closeAction: closeAction)
    }

    static func freemiumDBPPromotionScanEngagementResults(resultCount: Int,
                                                          brokerCount: Int,
                                                          proceedAction: @escaping () async -> Void,
                                                          closeAction: @escaping () -> Void) -> PromotionViewModel {

        var description = ""

        switch (resultCount, brokerCount) {
        case (1, _):
            description = UserText.homePagePromotionFreemiumDBPPostScanEngagementResultSingleMatchDescription
        case (let resultCount, 1):
            description = UserText.homePagePromotionFreemiumDBPPostScanEngagementResultSingleBrokerDescription(resultCount: resultCount)
        default:
            description = UserText.homePagePromotionFreemiumDBPPostScanEngagementResultPluralDescription(resultCount: resultCount,
                                                                                                   brokerCount: brokerCount)
        }

        let actionButtonText = UserText.homePagePromotionFreemiumDBPPostScanEngagementButtonTitle

        return PromotionViewModel(image: .informationRemover128,
                                  description: description,
                                  proceedButtonText: actionButtonText,
                                  proceedAction: proceedAction,
                                  closeAction: closeAction)
    }

    static func freemiumDBPPromotionScanEngagementNoResults(proceedAction: @escaping () async -> Void,
                                                            closeAction: @escaping () -> Void) -> PromotionViewModel {

        let description = UserText.homePagePromotionFreemiumDBPPostScanEngagementNoResultsDescription
        let actionButtonText = UserText.homePagePromotionFreemiumDBPPostScanEngagementButtonTitle

        return PromotionViewModel(image: .informationRemover128,
                                  description: description,
                                  proceedButtonText: actionButtonText,
                                  proceedAction: proceedAction,
                                  closeAction: closeAction)
    }
}
