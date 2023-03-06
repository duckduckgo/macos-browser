//
//  SyncSetupView.swift
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

import SwiftUI
import SyncUI

extension UserText: EnableSyncViewUserText {}
extension UserText: AskToSyncAnotherDeviceViewUserText {}
extension UserText: RecoverAccountViewUserText {}
extension UserText: SyncAnotherDeviceViewUserText {}
extension UserText: SyncSetupCompleteViewUserText {}
extension UserText: SaveRecoveryPDFViewUserText {}

extension SyncPreferences: EnableSyncViewModel {
    typealias EnableSyncViewUserText = UserText
}
extension SyncPreferences: AskToSyncAnotherDeviceViewModel {
    typealias AskToSyncAnotherDeviceViewUserText = UserText
}
extension SyncPreferences: RecoverAccountViewModel {
    typealias RecoverAccountViewUserText = UserText
}
extension SyncPreferences: SyncAnotherDeviceViewModel {
    typealias SyncAnotherDeviceViewUserText = UserText
}
extension SyncPreferences: SyncSetupCompleteViewModel {
    typealias SyncSetupCompleteViewUserText = UserText
}
extension SyncPreferences: SaveRecoveryPDFViewModel {
    typealias SaveRecoveryPDFViewUserText = UserText
}

struct SyncSetupView: View {
    @ObservedObject var model: SyncPreferences
    @ObservedObject var recoveryCodeModel: RecoveryCodeViewModel

    init(model: SyncPreferences, recoveryCodeModel: RecoveryCodeViewModel = .init()) {
        self.model = model
        self.recoveryCodeModel = recoveryCodeModel
    }

    var body: some View {
        content
            .alert(isPresented: $model.shouldShowErrorMessage) {
                Alert(title: Text("Unable to turn on Sync"), message: Text(model.errorMessage ?? "An error occurred"), dismissButton: .default(Text(UserText.ok)))
            }
    }

    @ViewBuilder var content: some View {
        switch model.flowStep {
        case .enableSync:
            EnableSyncView<SyncPreferences>().environmentObject(model)
        case .askToSyncAnotherDevice:
            AskToSyncAnotherDeviceView<SyncPreferences>().environmentObject(model)
        case .recoverAccount:
            RecoverAccountView<SyncPreferences>().environmentObject(model).environmentObject(recoveryCodeModel)
        case .syncAnotherDevice:
            SyncAnotherDeviceView<SyncPreferences>().environmentObject(model).environmentObject(recoveryCodeModel)
        case .deviceSynced:
            SyncSetupCompleteView<SyncPreferences>().environmentObject(model)
        case .saveRecoveryPDF:
            SaveRecoveryPDFView<SyncPreferences>().environmentObject(model)
        default:
            EmptyView()
        }
    }
}
