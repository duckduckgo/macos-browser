//
//  AdaptiveDarkModeWebsiteSettingsView.swift
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

struct AdaptiveDarkModeWebsiteSettingsView: View {
    @State private var toggle: Bool = false
    var body: some View {
        VStack (alignment: .leading, spacing: 14) {
            HStack (alignment: .center) {
                VStack(alignment: .leading) {
                    Text(UserText.adaptiveDarkModeWebsiteSettingsViewTitle)
                        .font(.headline)
                    if toggle {
                        Text(UserText.adaptiveDarkModeEnabledFor(website: "duck.com"))
                    } else {
                        Text(UserText.adaptiveDarkModeDisabledFor(website: "duck.com"))
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: $toggle)
                    .toggleStyle(.switch)
                
            }
            Divider()
            
            #warning("Settings should be a button")
            Text(UserText.adaptiveDarkModeWebsiteSettingsViewFooter)
                .font(.subheadline)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct AdaptiveDarkModeWebsiteSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        if #available(macOS 11.0, *) {
            AdaptiveDarkModeWebsiteSettingsView()
                .preferredColorScheme(.dark)
                .frame(width: 400, height: 105)
            
            AdaptiveDarkModeWebsiteSettingsView()
                .preferredColorScheme(.light)
                .frame(width: 400, height: 105)

        } else {
            AdaptiveDarkModeWebsiteSettingsView()
        }
    }
}
