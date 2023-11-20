//
//  DataImportProfilePicker.swift
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

struct DataImportProfilePicker: View {

    private let profiles: [DataImport.BrowserProfile]
    @Binding private var selectedProfile: DataImport.BrowserProfile?

    init(profileList: DataImport.BrowserProfileList?, selectedProfile: Binding<DataImport.BrowserProfile?>) {
        self.profiles = profileList?.profiles ?? []
        self._selectedProfile = selectedProfile
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if profiles.count > 1 {
                Text("Select Profile:")
                    .font(.headline)

                Picker(selection: Binding {
                    selectedProfile.flatMap(profiles.firstIndex(of:)) ?? 0
                } set: {
                    selectedProfile = profiles[safe: $0]
                }) {
                    ForEach(profiles.indices, id: \.self) { idx in
                        Text(profiles[idx].profileName)
                    }
                } label: {}
                    .pickerStyle(MenuPickerStyle())
            }
        }
    }

}

#Preview {
    DataImportProfilePicker(profileList: .init(browser: .chrome, profiles: [
        .init(browser: .chrome,
              profileURL: URL(fileURLWithPath: "/test/Default Profile")),
        .init(browser: .chrome,
              profileURL: URL(fileURLWithPath: "/test/Profile 1")),
        .init(browser: .chrome,
              profileURL: URL(fileURLWithPath: "/test/Profile 2")),
    ]), selectedProfile: Binding {
        .init(browser: .chrome,
              profileURL: URL(fileURLWithPath: "/test/Profile 1"))
    } set: {
        print("Profile selected:", $0.debugDescription ?? "<nil>")
    })
}
