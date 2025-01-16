//
//  NewTabPageFreemiumDBPBannerProvider.swift
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
import NewTabPage

final class NewTabPageFreemiumDBPBannerProvider: NewTabPageFreemiumDBPBannerProviding {

    var bannerMessage: NewTabPageDataModel.FreemiumPIRBannerMessage? {
        guard let viewModel = model.viewModel else {
            return nil
        }
        return .init(viewModel)
    }

    var bannerMessagePublisher: AnyPublisher<NewTabPageDataModel.FreemiumPIRBannerMessage?, Never> {
        model.$viewModel.dropFirst()
            .map { viewModel in
                guard let viewModel else {
                    return nil
                }
                return NewTabPageDataModel.FreemiumPIRBannerMessage(viewModel)
            }
            .eraseToAnyPublisher()
    }

    func dismiss() async {
        model.viewModel?.closeAction()
    }

    func action() async {
        await model.viewModel?.proceedAction()
    }

    let model: FreemiumDBPPromotionViewCoordinator

    init(model: FreemiumDBPPromotionViewCoordinator) {
        self.model = model
    }
}

extension NewTabPageDataModel.FreemiumPIRBannerMessage {
    init(_ promotionViewModel: PromotionViewModel) {

        self.init(
            titleText: promotionViewModel.title,
            descriptionText: promotionViewModel.description,
            actionText: promotionViewModel.proceedButtonText
        )
    }
}
