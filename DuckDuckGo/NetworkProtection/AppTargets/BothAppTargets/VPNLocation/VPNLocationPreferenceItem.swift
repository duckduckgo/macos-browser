//
//  NetworkProtectionVPNLocationPreferenceItem.swift
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

import Foundation
import SwiftUI

struct VPNLocationPreferenceItem: View {
    let model: VPNLocationPreferenceItemModel
    @State private var isShowingLocationSheet: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 10) {
                switch model.icon {
                case .defaultIcon:
                    Image(systemName: "location.fill")
                        .resizable()
                        .frame(width: 20, height: 20)
                case .emoji(let string):
                    Text(string).font(.system(size: 20))
                }

                VStack(alignment: .leading) {
                    Text(model.title)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    if let subtitle = model.subtitle {
                        Text(model.title)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button("Change...") {
                    isShowingLocationSheet = true
                }
                .sheet(isPresented: $isShowingLocationSheet) {
                    Text("Hi, I'm a sheet")
                }
            }
        }
        .frame(idealWidth: .infinity, maxWidth: .infinity, alignment: .topLeading)
        .padding(10)
        .background(Color("BlackWhite1"))
        .roundedBorder()
    }

}

#endif
