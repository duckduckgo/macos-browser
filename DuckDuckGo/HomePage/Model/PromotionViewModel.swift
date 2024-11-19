//
//  PromotionViewModel.swift
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

extension HomePage.Models {

    /// Model for a `PromotionView` type
    final class PromotionViewModel: ObservableObject {

        let image: ImageResource
        let title: String?
        let description: String
        let proceedButtonText: String
        let proceedAction: () -> Void
        let closeAction: () -> Void

        init(image: ImageResource, title: String? = nil, description: String, proceedButtonText: String, proceedAction: @escaping () -> Void, closeAction: @escaping () -> Void) {
            self.image = image
            self.title = title
            self.description = description
            self.proceedButtonText = proceedButtonText
            self.proceedAction = proceedAction
            self.closeAction = closeAction
        }
    }
}
