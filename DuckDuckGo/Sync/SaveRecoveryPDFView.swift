//
//  SaveRecoveryPDFView.swift
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

struct SaveRecoveryPDFView: View {
    @EnvironmentObject var model: SyncSetupViewModel

    var device: SyncedDevice {
        model.preferences.syncedDevices.last!
    }

    var body: some View {
        SyncWizardStep {
            VStack(spacing: 20.0) {
                Image("SyncRecoveryPDF")
                Text(UserText.saveRecoveryPDF)
                    .font(.system(size: 17, weight: .bold))
                Text(UserText.recoveryPDFExplanation1)
                    .multilineTextAlignment(.center)
                Text(UserText.recoveryPDFExplanation2)
                    .multilineTextAlignment(.center)
            }
        } buttons: {
            Button(UserText.notNow) {
                model.onCancel()
            }
            Button(UserText.saveRecoveryPDF) {
                model.preferences.isEnabled = true
                model.onCancel()
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .frame(height: 314)
    }
}
