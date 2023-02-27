//
//  EnableSyncView.swift
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

struct EnableSyncView: View {
    @EnvironmentObject var model: SyncSetupViewModel

    var body: some View {
        SyncWizardStep {
            VStack(spacing: 20) {
                Image("SyncTurnOnDialog")
                Text(UserText.turnOnSyncQuestion)
                    .font(.system(size: 17, weight: .bold))
                Text(UserText.turnOnSyncExplanation1)
                    .multilineTextAlignment(.center)
                Text(UserText.turnOnSyncExplanation2)
                    .multilineTextAlignment(.center)
            }
        } buttons: {
            Button(UserText.cancel) {
                model.onCancel()
            }
            Button(UserText.turnOnSync) {
                model.flowState = .syncAnotherDevice
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
        .frame(width: 360, height: 314)
    }
}
