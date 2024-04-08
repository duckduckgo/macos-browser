//
//  PreferencesViews.swift
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

public struct TextMenuTitle: View {
    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(Const.Fonts.preferencePaneTitle)
    }
}

public struct TextMenuItemHeader: View {
    public let text: String
    public let bottomPadding: CGFloat

    public init(_ text: String, bottomPadding: CGFloat = 4) {
        self.text = text
        self.bottomPadding = bottomPadding
    }

    public var body: some View {
        Text(text)
            .font(Const.Fonts.preferencePaneSectionHeader)
            .padding(.bottom, bottomPadding)
    }
}

public struct TextMenuItemCaption: View {
    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixMultilineScrollableText()
            .foregroundColor(Color(.greyText))
    }
}

public struct ToggleMenuItem: View {
    public let title: String
    public let isOn: Binding<Bool>

    public init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self.isOn = isOn
    }

    public var body: some View {
        Toggle(title, isOn: isOn)
            .fixMultilineScrollableText()
            .toggleStyle(.checkbox)
    }
}

public struct ToggleMenuItemWithDescription: View {
    public let title: String
    public let description: String
    public let isOn: Binding<Bool>
    public let spacing: CGFloat

    public init(_ title: String, _ description: String, isOn: Binding<Bool>, spacing: CGFloat) {
        self.title = title
        self.description = description
        self.isOn = isOn
        self.spacing = spacing
    }

    public var body: some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fixMultilineScrollableText()

                TextMenuItemCaption(description)
            }
        }.toggleStyle(.checkbox)
    }
}

public struct SpacedCheckbox<Content>: View where Content: View {
    @ViewBuilder public let content: () -> Content

    public init(_ content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading) {
            content()
        }.padding(.bottom, Const.Spacing.groupedCheckboxesSeparation)
    }
}

public struct PreferencePane<Content>: View where Content: View {

    public let title: String?
    public let spacing: CGFloat
    @ViewBuilder public let content: () -> Content

    public init(_ title: String? = nil, spacing: CGFloat = 23, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            if let title {
                TextMenuTitle(title)
            }
            content()
        }
    }
}

public struct PreferencePaneSection<Content>: View where Content: View {

    public let header: String?
    public let spacing: CGFloat
    @ViewBuilder public let content: () -> Content

    public init(_ header: String? = nil, spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.header = header
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            if let header {
                TextMenuItemHeader(header)
            }
            content()
        }
        .padding(.bottom, 16)
    }
}

public struct PreferencePaneSubSection<Content>: View where Content: View {

    public let spacing: CGFloat
    @ViewBuilder public let content: () -> Content

    public init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .padding(.bottom, 4)
    }
}
