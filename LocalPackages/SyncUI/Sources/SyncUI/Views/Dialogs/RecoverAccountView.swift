//
//  RecoverAccountView.swift
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
import SwiftUIExtensions

struct RecoverAccountView: View {
    @EnvironmentObject var model: ManagementDialogModel
    @EnvironmentObject var recoveryCodeModel: RecoveryCodeViewModel
    let isRecovery: Bool
    var instructionText: String {
        if isRecovery {
            return UserText.recoverSyncedDataExplanation
        }
        return UserText.manuallyEnterCodeExplanation

    }
    var titleText: String {
        if isRecovery {
            return UserText.recoverSyncedDataTitle
        }
        return UserText.manuallyEnterCodeTitle
    }

    func submitRecoveryCode() {
        model.delegate?.recoverDevice(using: recoveryCodeModel.recoveryCode)
    }

    var body: some View {
        SyncDialog(spacing: 20.0) {
            Text(titleText)
                .font(.system(size: 17, weight: .bold))

            EnterCodeView(
                instructions: instructionText,
                buttonCaption: UserText.pasteFromClipboard) {
                    submitRecoveryCode()
                }.environmentObject(recoveryCodeModel)

        } buttons: {
            Button(UserText.cancel) {
                model.endFlow()
            }
            .buttonStyle(DismissActionButtonStyle())
            Button(UserText.submit) {
                submitRecoveryCode()
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: !recoveryCodeModel.shouldDisableSubmitButton))
            .disabled(recoveryCodeModel.shouldDisableSubmitButton)
        }
        .frame(width: 480, height: 432)
    }

}
