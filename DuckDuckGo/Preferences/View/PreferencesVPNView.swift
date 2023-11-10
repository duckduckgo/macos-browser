//
//  PreferencesPrivacyView.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

extension Preferences {

    struct VPNView: View {
        @ObservedObject var model: VPNPreferencesModel

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {

                // TITLE

                TextMenuTitle(text: UserText.vpn)
                
                // SECTION: Manage VPN

                PreferencePaneSection {
                    TextMenuItemHeader(text: UserText.manageVPNSettingsTitle)

                    ToggleMenuItem(title: "Connect on Login", isOn: $model.connectOnLogin)
                    TextMenuItemCaption(text: "Automatically connect to the VPN service when you login")

                    ToggleMenuItem(title: "Show VPN in menu bar", isOn: $model.isAutoconsentEnabled)
                    TextMenuItemCaption(text: "Display VPN status in menu bar, next to the Wi-Fi and Battery")

                    ToggleMenuItem(title: "Always ON", isOn: $model.isAutoconsentEnabled)
                        .disabled(true)
                    TextMenuItemCaption(text: "Display VPN status in menu bar, next to the Wi-Fi and Battery")

                    //ToggleMenuItem(title: "Killswitch", isOn: $model.isAutoconsentEnabled)
                    //TextMenuItemCaption(text: "Display VPN status in menu bar, next to the Wi-Fi and Battery")

                    ToggleMenuItem(title: "Exclude Local Networks", isOn: $model.isAutoconsentEnabled)
                    TextMenuItemCaption(text: "Let local traffic bypass the VPN and connect to devices on your local network, like a printer")


                    ToggleMenuItem(title: "Secure DNS", isOn: $model.isAutoconsentEnabled)
                        .disabled(true)
                    TextMenuItemCaption(text: "Prevents DNS leaks to your Internet service provider by routing DNS queries through the VPN tunnel to our own resolver. For your security, this feature cannot be disabled.")
                }

                // SECTION: VPN Notifications

                PreferencePaneSection {
                    TextMenuItemHeader(text: UserText.vpnNotificationsSettingsTitle)

                    ToggleMenuItem(title: "Get notified if your connection drops or VPN status changes", isOn: $model.isAutoconsentEnabled)
                }
            }
        }
    }
}
