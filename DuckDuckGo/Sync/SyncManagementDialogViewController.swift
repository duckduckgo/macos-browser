//
//  SyncManagementDialogViewController.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import AppKit
import SwiftUI
import SyncUI

extension SyncPreferences: SyncManagementDialogModel {
    typealias SyncManagementDialogUserText = UserText
    typealias EnableSyncViewUserText = UserText
    typealias AskToSyncAnotherDeviceViewUserText = UserText
    typealias RecoverAccountViewUserText = UserText
    typealias SyncAnotherDeviceViewUserText = UserText
    typealias SyncSetupCompleteViewUserText = UserText
    typealias SaveRecoveryPDFViewUserText = UserText
}

extension UserText: SyncManagementDialogUserText {}
extension UserText: EnableSyncViewUserText {}
extension UserText: AskToSyncAnotherDeviceViewUserText {}
extension UserText: RecoverAccountViewUserText {}
extension UserText: SyncAnotherDeviceViewUserText {}
extension UserText: SyncSetupCompleteViewUserText {}
extension UserText: SaveRecoveryPDFViewUserText {}


final class SyncManagementDialogViewController: NSViewController {

    init(_ syncPreferences: SyncPreferences) {
        self.syncPreferences = syncPreferences
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private weak var syncPreferences: SyncPreferences?

    override func loadView() {
        guard let syncPreferences else {
            assertionFailure("SyncPreferences was deallocated")
            view = NSView()
            return
        }
        let syncManagementDialog = SyncManagementDialog(model: syncPreferences)
        view = NSHostingView(rootView: syncManagementDialog)
    }

}
