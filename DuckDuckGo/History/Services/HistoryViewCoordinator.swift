//
//  HistoryViewCoordinator.swift
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
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
import HistoryView
import Persistence
import PixelKit

final class HistoryViewCoordinator {
    let actionsManager: HistoryViewActionsManager

    init(
        historyCoordinator: HistoryGroupingDataSource,
        notificationCenter: NotificationCenter = .default,
        fireDailyPixel: @escaping (PixelKitEvent) -> Void = { PixelKit.fire($0, frequency: .daily) }
    ) {
        actionsManager = HistoryViewActionsManager(historyCoordinator: historyCoordinator)

        notificationCenter.publisher(for: .historyWebViewDidAppear)
            .prefix(1)
            .sink { _ in
                fireDailyPixel(HistoryViewPixel.historyPageShown)
            }
            .store(in: &cancellables)
    }

    private var cancellables: Set<AnyCancellable> = []
}
