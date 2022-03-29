//
//  PreferencesDefaultBrowserView.swift
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
import AppKit
import Combine

extension Preferences {

    struct DefaultBrowserView: View {
        @ObservedObject var model: DefaultBrowserPreferences

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(UserText.defaultBrowser)
                    .font(Const.Fonts.preferencePaneTitle)

                Section {
                    HStack {
                        if model.isDefault {
                            Image("SolidCheckmark")
                            Text(UserText.isDefaultBrowser)
                        } else {
                            Image("Warning")
                            Text(UserText.isNotDefaultBrowser)
                            Button("Make DuckDuckGo Default...") {
                                model.becomeDefault()
                            }
                        }
                    }
                }
            }
        }
    }
}
