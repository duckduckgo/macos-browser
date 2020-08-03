//
//  TabViewModel.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

class TabViewModel {

    private(set) var tab: Tab
    private var cancelables = Set<AnyCancellable>()

    @Published var canGoForward: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canReload: Bool = false
    @Published var isLoading: Bool = false

    init(tab: Tab) {
        self.tab = tab

        bindUrl()
    }

    var addressBarString: String {
        guard let url = tab.url else {
            return ""
        }

        if let searchQuery = url.searchQuery {
            return searchQuery
        } else {
            return url.absoluteString
                .dropPrefix(URL.Scheme.https.separated())
                .dropPrefix(URL.Scheme.http.separated())
        }
    }

    private func bindUrl() {
        tab.$url.sinkAsync { _ in self.updateCanReaload() } .store(in: &cancelables)
    }

    private func updateCanReaload() {
        self.canReload = self.tab.url != nil
    }

}
