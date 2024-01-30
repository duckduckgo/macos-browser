//
//  ContentBlockingRulesUpdateObserver.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import Combine
import BrowserServicesKit

final class ContentBlockingRulesUpdateObserver {

    @Published public private(set) var pendingUpdates = [String: String]()

    public private(set) weak var tabViewModel: TabViewModel?
    private var onPendingUpdates: (() -> Void)?
    private var rulesRecompilationCancellable: AnyCancellable?

    public func updateTabViewModel(_ tabViewModel: TabViewModel, onPendingUpdates: @escaping () -> Void) {
        rulesRecompilationCancellable?.cancel()
        rulesRecompilationCancellable = nil

        self.tabViewModel = tabViewModel
        self.onPendingUpdates = onPendingUpdates

        bindContentBlockingRulesRecompilation(publisher: (ContentBlocking.shared as? AppContentBlocking)!.userContentUpdating.userContentBlockingAssets)
    }

    public func startCompilation(for domain: String, token: ContentBlockerRulesManager.CompletionToken ) {
        pendingUpdates[token] = domain
        onPendingUpdates?()
    }

    private func bindContentBlockingRulesRecompilation<Pub: Publisher>(publisher: Pub) where Pub.Output == UserContentUpdating.NewContent,
                                                                                                Pub.Failure == Never {
        rulesRecompilationCancellable = publisher
            .compactMap(\.nonEmptyCompletionTokens)
            .receive(on: RunLoop.main)
            .sink { [weak self] completionTokens in
                dispatchPrecondition(condition: .onQueue(.main))

                guard let self = self, !self.pendingUpdates.isEmpty else { return }

                var didUpdate = false
                for token in completionTokens {
                    // swiftlint:disable:next for_where
                    if self.pendingUpdates.removeValue(forKey: token) != nil {
                        didUpdate = true
                    }
                }

                if didUpdate {
                    self.tabViewModel?.reload()
                    self.onPendingUpdates?()
                }
            }
    }
}

private extension UserContentUpdating.NewContent {

    var nonEmptyCompletionTokens: [ContentBlockerRulesManager.CompletionToken]? {
        let nonEmptyTokens = rulesUpdate.completionTokens.filter { !$0.isEmpty }
        if nonEmptyTokens.isEmpty {
            return nil
        }
        return nonEmptyTokens
    }
}
