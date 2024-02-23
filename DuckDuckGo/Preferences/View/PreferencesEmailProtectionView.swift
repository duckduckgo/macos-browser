//
//  PreferencesEmailProtectionView.swift
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

import AppKit
import Combine
import PreferencesViews
import SwiftUI
import SwiftUIExtensions
import BrowserServicesKit

extension Preferences {
    struct EmailProtectionView: View {
            var emailManager: EmailManager

            // Local state to trigger the view refresh
            @State private var needsRefresh: Bool = false
            @State private var notificationToken: AnyCancellable?

            var body: some View {
                PreferencePane("Email Protection") {
                    // SECTION 1: Email
                    PreferencePaneSection {

                        PreferencePaneSubSection {
                            if emailManager.isSignedIn {
                                Button(UserText.emailOptionsMenuManageAccountSubItem + "…") {
                                    WindowControllersManager.shared.show(url: EmailUrls().emailProtectionAccountLink,
                                                                         source: .ui,
                                                                         newTab: true)
                                }
                                Button(UserText.emailOptionsMenuTurnOffSubItem) {
                                    let alert = NSAlert.disableEmailProtection()
                                    let response = alert.runModal()
                                    if response == .alertFirstButtonReturn {
                                        try? emailManager.signOut()
                                        needsRefresh.toggle() // Toggle to refresh the view
                                    }
                                }
                            } else {
                                Button(UserText.emailOptionsMenuTurnOnSubItem + "…") {
                                    WindowControllersManager.shared.show(url: EmailUrls().emailProtectionLink,
                                                                         source: .ui,
                                                                         newTab: true)
                                }
                            }
                        }

                        PreferencePaneSubSection {
                            VStack(alignment: .leading, spacing: 0) {
                                TextMenuItemCaption(UserText.emailProtectionExplanation)
                                TextButton(UserText.learnMore) {
                                    WindowControllersManager.shared.show(url: .duckDuckGoEmailInfo,
                                                                         source: .ui,
                                                                         newTab: true)
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    subscribeToNotifications()
                }

            }

        private func subscribeToNotifications() {
            notificationToken = Publishers.Merge(
                NotificationCenter.default.publisher(for: .emailDidSignIn),
                NotificationCenter.default.publisher(for: .emailDidSignOut)
            )
            .receive(on: RunLoop.main)
            .sink { _ in
                // Refresh the view
                self.needsRefresh.toggle()
            }
        }
    }
}
