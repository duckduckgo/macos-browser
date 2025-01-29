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

public enum ManagementDialogKind: Equatable {
    case deleteAccount(_ devices: [SyncDevice])
    case turnOffSync
    case deviceDetails(_ device: SyncDevice)
    case removeDevice(_ device: SyncDevice)
    case syncWithAnotherDevice(code: String)
    case prepareToSync
    case saveRecoveryCode(_ code: String)
    case nowSyncing
    case syncWithServer
    case enterRecoveryCode(code: String)
    case recoverSyncedData
    case empty
}

public struct ManagementDialog: View {
    @ObservedObject public var model: ManagementDialogModel
    @ObservedObject public var recoveryCodeModel: RecoveryCodeViewModel

    var errorTitle: String {
        return model.syncErrorMessage?.type.title ?? "Sync Error"
    }

    var errorDescription: String {
        guard let typeDescription = model.syncErrorMessage?.type.description,
              let errorDescription = model.syncErrorMessage?.errorDescription
        else {
            return ""
        }
        return typeDescription + "\n" + errorDescription
    }

    var buttonTitle: String {
        return model.syncErrorMessage?.type.buttonTitle ?? UserText.ok
    }

    public init(model: ManagementDialogModel, recoveryCodeModel: RecoveryCodeViewModel = .init()) {
        self.model = model
        self.recoveryCodeModel = recoveryCodeModel
    }

    public var body: some View {
        content
            .alert(isPresented: $model.shouldShowErrorMessage) {
                if model.shouldShowSwitchAccountsMessage {
                    Alert(
                        title: Text(UserText.syncAlertSwitchAccountTitle),
                        message: Text(UserText.syncAlertSwitchAccountMessage),
                        primaryButton: .default(Text(UserText.syncAlertSwitchAccountButton)) {
                            model.userConfirmedSwitchAccounts(recoveryCode: recoveryCodeModel.recoveryCode)
                        },
                        secondaryButton: .cancel {
                            model.endFlow()
                        }
                    )
                } else {
                    Alert(
                        title: Text(errorTitle),
                        message: Text(errorDescription),
                        dismissButton: .default(Text(buttonTitle)) {
                            model.endFlow()
                        }
                    )
                }
            }
    }

    @ViewBuilder var content: some View {
        Group {
            switch model.currentDialog {
            case .turnOffSync:
                TurnOffSyncView()
            case .deviceDetails(let device):
                DeviceDetailsView(device: device)
            case .removeDevice(let device):
                RemoveDeviceView(device: device)
            case .deleteAccount(let devices):
                DeleteAccountView(devices: devices)
            case .syncWithAnotherDevice(let code):
                SyncWithAnotherDeviceView(code: code)
            case .prepareToSync:
                PreparingToSyncView()
            case .saveRecoveryCode(let code):
                SaveRecoveryPDFView(code: code)
            case .nowSyncing:
                DeviceSyncedView()
            case .syncWithServer:
                SyncWithServerView()
            case .enterRecoveryCode(let code):
                EnterRecoveryCodeView(code: code)
            case .recoverSyncedData:
                RecoverSyncedDataView()
            default:
                EmptyView()
            }
        }
        .environmentObject(model)
        .environmentObject(recoveryCodeModel)
    }
}
