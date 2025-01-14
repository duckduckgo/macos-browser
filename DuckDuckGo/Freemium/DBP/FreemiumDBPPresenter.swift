//
//  FreemiumDBPPresenter.swift
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
import Freemium

/// Conforming types provide functionality to show Freemium DBP
protocol FreemiumDBPPresenter {
    @MainActor
    func showFreemiumDBPAndSetActivated(windowControllerManager: WindowControllersManagerProtocol?)
}

/// Default implementation of `FreemiumDBPPresenter`
final class DefaultFreemiumDBPPresenter: FreemiumDBPPresenter {

    private var freemiumDBPStateManager: FreemiumDBPUserStateManager

    init(freemiumDBPStateManager: FreemiumDBPUserStateManager = DefaultFreemiumDBPUserStateManager(userDefaults: .dbp)) {
        self.freemiumDBPStateManager = freemiumDBPStateManager
    }

    @MainActor
    /// Displays Freemium DBP
    func showFreemiumDBPAndSetActivated(windowControllerManager: WindowControllersManagerProtocol? = nil) {

        let windowControllerManager = windowControllerManager ?? WindowControllersManager.shared
        freemiumDBPStateManager.didActivate = true
        windowControllerManager.showTab(with: .dataBrokerProtection)
    }
}
