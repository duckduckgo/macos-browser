//
//  SyncAlertsPresenter.swift
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

public protocol SyncAlertsPresenting {
    func showSyncPausedAlert(title: String, informative: String)
}

public struct SyncAlertsPresenter: SyncAlertsPresenting {
    public init () {}
    public func showSyncPausedAlert(title: String, informative: String) {
        Task { @MainActor in
                let alert =  NSAlert.syncPaused(title: title, informative: informative)
                let response = alert.runModal()

                switch response {
                case .alertSecondButtonReturn:
                    alert.window.sheetParent?.endSheet(alert.window)
                    WindowControllersManager.shared.showPreferencesTab(withSelectedPane: .sync)
                default:
                    break
                }
            }

    }
}
