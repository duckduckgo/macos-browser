//
//  PreferencesAccessibilityView.swift
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
import PreferencesUI_macOS
import SwiftUI
import SwiftUIExtensions

extension Preferences {

    struct AccessibilityView: View {
        @ObservedObject var model: AccessibilityPreferences

        var body: some View {
            PreferencePane(UserText.accessibility) {

                // SECTION 1: Zoom Setting
                PreferencePaneSection {

                    HStack {
                        Text(UserText.zoomPickerTitle)
                        NSPopUpButtonView(selection: $model.defaultPageZoom) {
                            let button = NSPopUpButton()
                            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)

                            for value in DefaultZoomValue.allCases {
                                let item = button.menu?.addItem(withTitle: value.displayString, action: nil, keyEquivalent: "")
                                item?.representedObject = value
                            }
                            return button
                        }
                    }
                }

            }
        }
    }
}
