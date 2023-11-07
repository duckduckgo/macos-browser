//
//  NetworkProtectionWaitlistRootView.swift
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

#if NETWORK_PROTECTION

import SwiftUI

struct NetworkProtectionWaitlistRootView: View {
    @EnvironmentObject var model: WaitlistViewModel

    var body: some View {
        Group {
            switch model.viewState {
            case .notOnWaitlist, .joiningWaitlist:
                JoinWaitlistView(viewData: NetworkProtectionJoinWaitlistViewData())
            case .joinedWaitlist(let state):
                JoinedWaitlistView(viewData: NetworkProtectionJoinedWaitlistViewData(),
                                   notificationsAllowed: state == .notificationAllowed)
            case .invited:
                InvitedToWaitlistView(viewData: NetworkProtectionInvitedToWaitlistViewData())
            case .termsAndConditions:
                WaitlistTermsAndConditionsView(viewData: NetworkProtectionWaitlistTermsAndConditionsViewData()) {
                    NetworkProtectionTermsAndConditionsContentView()
                }
            case .readyToEnable:
                EnableWaitlistFeatureView(viewData: EnableNetworkProtectionViewData())
            }
        }
        .environmentObject(model)
    }
}

#endif

#if DBP

import SwiftUI

struct DataBrokerProtectionWaitlistRootView: View {
    @EnvironmentObject var model: WaitlistViewModel

    var body: some View {
        Group {
            switch model.viewState {
            case .notOnWaitlist, .joiningWaitlist:
                JoinWaitlistView(viewData: DataBrokerProtectionJoinWaitlistViewData())
            case .joinedWaitlist(let state):
                JoinedWaitlistView(viewData: DataBrokerProtectionJoinedWaitlistViewData(),
                                   notificationsAllowed: state == .notificationAllowed)
            case .invited:
                InvitedToWaitlistView(viewData: DataBrokerProtectionInvitedToWaitlistViewData())
            case .termsAndConditions:
                WaitlistTermsAndConditionsView(viewData: DataBrokerProtectionWaitlistTermsAndConditionsViewData()) {
                    DataBrokerProtectionTermsAndConditionsContentView()
                }
            case .readyToEnable:
                EnableWaitlistFeatureView(viewData: EnableDataBrokerProtectionViewData())
            }
        }
        .environmentObject(model)
    }
}

#endif
