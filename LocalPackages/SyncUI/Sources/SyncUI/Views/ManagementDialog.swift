//
//  ManagementDialog.swift
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

public enum ManagementDialogKind {
    case enableSync, recoverAccount, askToSyncAnotherDevice, syncAnotherDevice, deviceSynced, saveRecoveryPDF, turnOffSync
}

public struct ManagementDialog: View {
    @ObservedObject public var model: ManagementDialogModel
    @ObservedObject public var recoveryCodeModel: RecoveryCodeViewModel

    public init(model: ManagementDialogModel, recoveryCodeModel: RecoveryCodeViewModel = .init()) {
        self.model = model
        self.recoveryCodeModel = recoveryCodeModel
    }

    public var body: some View {
        content
            .alert(isPresented: $model.shouldShowErrorMessage) {
                Alert(
                    title: Text("Unable to turn on Sync"),
                    message: Text(model.errorMessage ?? "An error occurred"),
                    dismissButton: .default(Text(UserText.ok))
                )
            }
    }

    @ViewBuilder var content: some View {
        Group {
            switch model.currentDialog {
            case .enableSync:
                EnableSyncView()
            case .askToSyncAnotherDevice:
                AskToSyncAnotherDeviceView()
            case .recoverAccount:
                RecoverAccountView()
            case .syncAnotherDevice:
                SyncAnotherDeviceView()
            case .deviceSynced:
                SyncSetupCompleteView()
            case .saveRecoveryPDF:
                SaveRecoveryPDFView()
            case .turnOffSync:
                TurnOffSyncView()
            default:
                EmptyView()
            }
        }
        .environmentObject(model)
        .environmentObject(recoveryCodeModel)
    }
}
