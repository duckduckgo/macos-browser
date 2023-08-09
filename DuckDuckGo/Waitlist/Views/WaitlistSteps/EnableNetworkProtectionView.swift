//
//  EnableNetworkProtectionView.swift
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

struct EnableNetworkProtectionView: View {
    @EnvironmentObject var model: WaitlistViewModel

    var body: some View {
        WaitlistDialogView {
            VStack(spacing: 16.0) {
                Image("Network-Protection-256")

                Text("Ready to enable Network Protection?")
                    .font(.system(size: 17, weight: .bold))

                Text("Look for the globe icon in the browser toolbar or in the Mac menu bar.\n\nYou'll be asked to Allow a VPN connection once when setting up Network Protection the first time.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black.opacity(0.88))

                Text("Network Protection is free to use during the beta.")
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.60))
            }
        } buttons: {
            Button("Got It") {
                model.perform(action: .close)
            }
            .buttonStyle(DefaultActionButtonStyle(enabled: true))
        }
    }
}
