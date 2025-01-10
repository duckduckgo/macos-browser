//
//  CapturingNewTabPageFreemiumDBPBannerProvider.swift
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
import NewTabPage

final class CapturingNewTabPageFreemiumDBPBannerProvider: NewTabPageFreemiumDBPBannerProviding {
    @Published var bannerMessage: NewTabPageDataModel.FreemiumPIRBannerMessage?

    var bannerMessagePublisher: AnyPublisher<NewTabPageDataModel.FreemiumPIRBannerMessage?, Never> {
        $bannerMessage.dropFirst().eraseToAnyPublisher()
    }

    func dismiss() async {
        dismissCallCount += 1
        await _dismiss()
    }

    func action() async {
        actionCallCount += 1
        await _action()
    }

    var dismissCallCount: Int = 0
    var actionCallCount: Int = 0

    // swiftlint:disable identifier_name
    var _dismiss: () async -> Void = {}
    var _action: () async -> Void = {}
    // swiftlint:enable identifier_name
}
