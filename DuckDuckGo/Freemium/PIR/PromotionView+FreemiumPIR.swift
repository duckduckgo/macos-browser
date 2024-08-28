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
    static func freemiumPIRPromotion(proceedAction: @escaping () -> Void, closeAction: @escaping () -> Void) -> PromotionViewModel {
        
        let description = "Find your personal information from sites that store and sell it."
        let actionButtonText = "Scan"

        return PromotionViewModel(image: .gift96,
                                  description: description,
                                  proceedButtonText: actionButtonText,
                                  proceedAction: proceedAction,
                                  closeAction: closeAction)
    }
}
