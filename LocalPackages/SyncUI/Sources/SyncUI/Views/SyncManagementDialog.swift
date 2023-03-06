//
//  SyncManagementDialog.swift
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

//extension UserText: EnableSyncViewUserText {}
//extension UserText: AskToSyncAnotherDeviceViewUserText {}
//extension UserText: RecoverAccountViewUserText {}
//extension UserText: SyncAnotherDeviceViewUserText {}
//extension UserText: SyncSetupCompleteViewUserText {}
//extension UserText: SaveRecoveryPDFViewUserText {}
//
//extension SyncPreferences: EnableSyncViewModel {
//    typealias EnableSyncViewUserText = UserText
//}
//extension SyncPreferences: AskToSyncAnotherDeviceViewModel {
//    typealias AskToSyncAnotherDeviceViewUserText = UserText
//}
//extension SyncPreferences: RecoverAccountViewModel {
//    typealias RecoverAccountViewUserText = UserText
//}
//extension SyncPreferences: SyncAnotherDeviceViewModel {
//    typealias SyncAnotherDeviceViewUserText = UserText
//}
//extension SyncPreferences: SyncSetupCompleteViewModel {
//    typealias SyncSetupCompleteViewUserText = UserText
//}
//extension SyncPreferences: SaveRecoveryPDFViewModel {
//    typealias SaveRecoveryPDFViewUserText = UserText
//}

public protocol SyncManagementDialogModel: ObservableObject,
                                           EnableSyncViewModel,
                                           AskToSyncAnotherDeviceViewModel,
                                           RecoverAccountViewModel,
                                           SyncAnotherDeviceViewModel,
                                           SyncSetupCompleteViewModel,
                                           SaveRecoveryPDFViewModel {

    associatedtype SyncManagementDialogUserText: SyncUI.SyncManagementDialogUserText

    var currentDialog: SyncManagementDialogKind? { get }

    var shouldShowErrorMessage: Bool { get set }
    var errorMessage: String? { get }
}

public protocol SyncManagementDialogUserText {
    static var ok: String { get }
}

public enum SyncManagementDialogKind {
    case enableSync, recoverAccount, askToSyncAnotherDevice, syncAnotherDevice, deviceSynced, saveRecoveryPDF
}

public struct SyncManagementDialog<ViewModel>: View where ViewModel: SyncManagementDialogModel {
    typealias UserText = ViewModel.SyncManagementDialogUserText

    @ObservedObject public var model: ViewModel
    @ObservedObject public var recoveryCodeModel: RecoveryCodeViewModel

    public init(model: ViewModel, recoveryCodeModel: RecoveryCodeViewModel = .init()) {
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
        switch model.currentDialog {
        case .enableSync:
            EnableSyncView<ViewModel>().environmentObject(model)
        case .askToSyncAnotherDevice:
            AskToSyncAnotherDeviceView<ViewModel>().environmentObject(model)
        case .recoverAccount:
            RecoverAccountView<ViewModel>().environmentObject(model).environmentObject(recoveryCodeModel)
        case .syncAnotherDevice:
            SyncAnotherDeviceView<ViewModel>().environmentObject(model).environmentObject(recoveryCodeModel)
        case .deviceSynced:
            SyncSetupCompleteView<ViewModel>().environmentObject(model)
        case .saveRecoveryPDF:
            SaveRecoveryPDFView<ViewModel>().environmentObject(model)
        default:
            EmptyView()
        }
    }
}
