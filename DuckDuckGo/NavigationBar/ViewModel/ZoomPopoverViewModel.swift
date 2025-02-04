//
//  ZoomPopoverViewModel.swift
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

final class ZoomPopoverViewModel: ObservableObject {
    let tabViewModel: TabViewModel
    @Published var zoomLevel: DefaultZoomValue = .percent100
    private var cancellables = Set<AnyCancellable>()

    init(tabViewModel: TabViewModel) {
        self.tabViewModel = tabViewModel
        zoomLevel = tabViewModel.zoomLevel
        tabViewModel.zoomLevelSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.zoomLevel = newValue
            }.store(in: &cancellables)
    }

    func zoomIn() {
        tabViewModel.tab.webView.zoomIn()
    }

    func zoomOut() {
        tabViewModel.tab.webView.zoomOut()
    }

    func reset() {
        tabViewModel.tab.webView.resetZoomLevel()
    }

}
