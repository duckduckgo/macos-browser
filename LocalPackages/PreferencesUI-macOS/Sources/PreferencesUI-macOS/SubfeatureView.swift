//
//  SubfeatureView.swift
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
import SwiftUIExtensions

public struct SubfeatureView: View {
    public var icon: Image
    public var title: String
    public var description: String
    public var buttonName: String?
    public var buttonAction: (() -> Void)?
    public var enabled: Bool

    public init(icon: Image, title: String, description: String, buttonName: String? = nil, buttonAction: (() -> Void)? = nil, enabled: Bool = true) {

        self.icon = icon
        self.title = title
        self.description = description
        self.buttonName = buttonName
        self.buttonAction = buttonAction
        self.enabled = enabled
    }

    public var body: some View {
        VStack(alignment: .center) {
            VStack {
                HStack(alignment: .center, spacing: 8) {
                    icon
                        .padding(4)
                        .background(Color(.badgeBackground))
                        .cornerRadius(4)

                    VStack (alignment: .leading) {
                        Text(title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixMultilineScrollableText()
                            .font(.body)
                            .foregroundColor(Color(.textPrimary))
                        Spacer()
                            .frame(height: 4)
                        Text(description)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixMultilineScrollableText()
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(Color(.textSecondary))
                    }

                    if let name = buttonName, !name.isEmpty, let action = buttonAction {
                        Button(name) { action() }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.6)
    }
}
