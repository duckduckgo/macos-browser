//
//  SyncSetupCompleteView.swift
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

//struct SyncSetupCompleteView: View {
//    @EnvironmentObject var model: SyncSetupViewModel
//
//    var device: SyncedDevice {
//        .init(kind: .mobile, name: "Dave's iPhone 14", id: UUID().uuidString)
//    }
//
//    var body: some View {
//        SyncWizardStep(spacing: 20.0) {
//            VStack(spacing: 20) {
//                Image("SyncSetupComplete")
//                Text(UserText.deviceSynced)
//                    .font(.system(size: 17, weight: .bold))
//                Text(UserText.deviceSyncedExplanation)
//                    .multilineTextAlignment(.center)
//
//                Outline {
//                    SyncPreferencesRow {
//                        SyncedDeviceIcon(kind: device.kind)
//                    } centerContent: {
//                        Text(device.name)
//                    }
//                }
//            }
//        } buttons: {
//            Button(UserText.next) {
//                model.flowState = .saveRecoveryPDF
//            }
//        }
//        .frame(width: 360, height: 298)
//    }
//}
