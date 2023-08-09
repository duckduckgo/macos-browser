//
//  WaitlistRootView.swift
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

struct WaitlistRootView: View {
    @EnvironmentObject var model: WaitlistViewModel

    let sizeChanged: (CGFloat) -> Void

    @State var viewHeight: CGFloat = 0.0 {
        didSet {
            sizeChanged(viewHeight)
        }
    }

    var body: some View {
        Group {
            switch model.waitlistState {
            case .notOnWaitlist, .joiningWaitlist:
                JoinWaitlistView()
            case .joinedWaitlist:
                JoinedWaitlistView()
            case .invited:
                InvitedToWaitlistView()
            case .termsAndConditions:
                NetworkProtectionTermsAndConditionsView()
            case .readyToEnable:
                EnableNetworkProtectionView()
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.onAppear {
                    viewHeight = proxy.size.height
                }
            }
        )
        .environmentObject(model)
    }
}
