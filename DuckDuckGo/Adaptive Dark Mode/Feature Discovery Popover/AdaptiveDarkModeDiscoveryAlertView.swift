//
//  AdaptiveDarkModeDiscoveryAlertView.swift
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

struct AdaptiveDarkModeDiscoveryAlertView: View {
    private let defaultSpacing: CGFloat = 15
    
    var body: some View {
        HStack(spacing: defaultSpacing) {
            Image("AdaptiveDarkModeOptIn")
            VStack (alignment: .leading, spacing: defaultSpacing) {
                VStack (alignment: .leading, spacing: 5) {
                    Text(UserText.adaptiveDarkModeOptInPopoverTitle)
                    .font(.headline)
                
                    Text(UserText.adaptiveDarkModeOptInPopoverMessage)
                }
                HStack {
                    Button {
                        print("No")
                    } label: {
                        Text(UserText.adaptiveDarkModeOptInPopoverDenyButton)
                            .frame(maxWidth: .infinity)
                    }
                    Button {
                        print("Yes")
                    } label: {
                        Text(UserText.adaptiveDarkModeOptInPopoverConfirmButton)
                            .frame(maxWidth: .infinity)
                    }
                }.frame(maxWidth: .infinity)
            }.frame(width: 268)
        }.padding(defaultSpacing)
    }
}

struct AdaptiveDarkModeDiscoveryAlertView_Previews: PreviewProvider {
    static var previews: some View {
        if #available(macOS 11.0, *) {
            AdaptiveDarkModeDiscoveryAlertView()
                .preferredColorScheme(.dark)
            
            AdaptiveDarkModeDiscoveryAlertView()
                .preferredColorScheme(.light)
        } else {
            AdaptiveDarkModeDiscoveryAlertView()
        }
    }
}
