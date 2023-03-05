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

extension UserText: EnableSyncViewModelUserText {}

extension SyncPreferences: EnableSyncViewModel {
    typealias SyncUserText = UserText
}

struct SyncSetupView: View {
    @ObservedObject var model: SyncPreferences

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
        case .syncAnotherDevice:
            SyncAnotherDeviceView().environmentObject(model)
        case .recoverAccount:
            RecoverAccountView().environmentObject(model)
//        case .syncNewDevice:
//            SyncNewDeviceView().environmentObject(model)
//        case .deviceSynced:
//            SyncSetupCompleteView().environmentObject(model)
//        case .saveRecoveryPDF:
//            SaveRecoveryPDFView().environmentObject(model)
        default:
            Text("WTF")
        }
    }
}
