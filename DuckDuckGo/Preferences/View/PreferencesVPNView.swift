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

                    ToggleMenuItem(title: UserText.vpnConnectOnLoginSettingTitle, isOn: $model.connectOnLogin)
                    TextMenuItemCaption(text: UserText.vpnConnectOnLoginSettingDescription)

                    ToggleMenuItem(title: UserText.vpnShowInMenuBarSettingTitle, isOn: $model.showInMenuBar)
                    TextMenuItemCaption(text: UserText.vpnShowInMenuBarSettingDescription)

                    ToggleMenuItem(title: UserText.vpnAlwaysONSettingTitle, isOn: $model.alwaysON)
                        .disabled(true)
                    TextMenuItemCaption(text: UserText.vpnAlwaysOnSettingDescription)

                    ToggleMenuItem(title: UserText.vpnExcludeLocalNetworksSettingTitle, isOn: $model.excludeLocalNetworks)
                    TextMenuItemCaption(text: UserText.vpnExcludeLocalNetworksSettingDescription)

                    ToggleMenuItem(title: UserText.vpnSecureDNSSettingTitle, isOn: $model.secureDNS)
                        .disabled(true)
                    TextMenuItemCaption(text: UserText.vpnSecureDNSSettingDescription)
                }

                // SECTION: VPN Notifications

                PreferencePaneSection {
                    TextMenuItemHeader(text: UserText.vpnNotificationsSettingsTitle)

                    ToggleMenuItem(title: UserText.vpnStatusChangeNotificationSettingTitle, isOn: $model.notifyStatusChanges)
                }

                // SECTION: Uninstall

                PreferencePaneSection {
                    TextMenuItemHeader(text: UserText.vpnAdvancedSettingsTitle)

                    Button(UserText.uninstallVPNButtonTitle) {
                        model.uninstallVPN()
                    }
                }
            }
        }
    }
}
