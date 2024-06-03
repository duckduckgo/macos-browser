//
//  UpdateNotificationView.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

struct UpdateNotificationView: View {
    let icon: NSImage
    let text: String
    let onClose: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 16, height: 16)
                .padding(.leading, 10)

            Text(text)

            Spacer()

            Button(action: {
                onClose()
            }) {
                Image(.updateNotificationClose)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 10)
        }
        .frame(height: 60)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 10)
        .padding()
        .onTapGesture {
            onTap()
        }
    }
}

struct UpdateNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        UpdateNotificationView(icon: NSImage(named: NSImage.cautionName)!, text: "Critical update required. Relaunch to update.", onClose: {}, onTap: {})
    }
}
