//
//  SyncTabs.swift
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

extension HomePage.Views {

struct SyncTabs: View {

    @EnvironmentObject var model: HomePage.Models.SyncTabsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.deviceTabs) { deviceTabs in
                Text(deviceTabs.deviceId)
                    .font(.system(size: 12).bold())
                    .foregroundColor(.secondary)
                    .padding(.bottom, 2)
                Rectangle()
                    .foregroundColor(Color("BlackWhite10"))
                    .frame(maxWidth: .infinity, idealHeight: 1)
                    .padding(.bottom, 12)
                ForEach(deviceTabs.deviceTabs) { tabInfo in
                    Button {
                        model.open(tabInfo.url)
                    } label: {
                        Text(tabInfo.title.isEmpty ? tabInfo.url.absoluteString : tabInfo.title)
                            .lineLimit(1)
                            .padding(.leading, 12)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 2)
                    Rectangle()
                        .foregroundColor(Color("BlackWhite10"))
                        .frame(maxWidth: .infinity, idealHeight: 1)
                        .padding(.leading, 12)
                        .padding(.bottom, 6)
                }
            }
        }
//        List {
//            ForEach(model.deviceTabs) { deviceTabs in
//                Section(header: Text(deviceTabs.deviceId)) {
//                    ForEach(deviceTabs.deviceTabs) { tabInfo in
//                        Button {
//                            model.open(tabInfo.url)
//                        } label: {
//                            Text(tabInfo.title.isEmpty ? tabInfo.url.absoluteString : tabInfo.title)
//                                .lineLimit(1)
//                        }
//                        .buttonStyle(.plain)
//                    }
//                }
//            }
//        }
//        .frame(minHeight: 200)
    }
}

}
