//
//  PreferencesPrivacyProView.swift
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

extension Preferences {

    struct PrivacyProView: View {
        @ObservedObject var model: PrivacyProPreferencesModel
        @State private var showingSheet = false

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {

                // TITLE
                TextMenuTitle(text: "Privacy Pro")

                Spacer()
                    .frame(height: 20)

                Button("show") {
                    showingSheet.toggle()
                }
                .sheet(isPresented: $showingSheet) {
                    if #available(macOS 12.0, *) {
                        SheetView()
                    }
                }

                VStack {
                    if model.isSignedIn {
                        HeaderActiveView(title: "Privacy Pro is active on this device",
                                   description: "Your monthly Privacy Pro subscription renews on April 20, 2027.",
                                   button1Name: "Add to Another Device…", button2Name: "Manage Subscription")
                    } else {
                        HeaderView(title: "One subscription, three advanced protections",
                                   description: "Get enhanced protection across all your devices and reduce your online footprint for as little as $9.99/mo.",
                                   button1Name: "Learn More", button2Name: "I Have a Subscription")
                    }

                    Divider()
                        .foregroundColor(Color.secondary)
                        .padding(.horizontal, -10)

                    SectionView(title: "VPN",
                                description: "Full-device protection with the VPN built for speed and security.",
                                buttonName: model.isSignedIn ? "Manage" : "")

                    Divider()
                        .foregroundColor(Color.secondary)

                    SectionView(title: "Personal Information Removal",
                                description: "Find and remove your personal information from sites that store and sell it.",
                                buttonName: model.isSignedIn ? "View" : "")

                    Divider()
                        .foregroundColor(Color.secondary)

                    SectionView(title: "Identity Theft Restoration",
                                description: "Restore stolen accounts and financial losses in the event of identity theft.",
                                buttonName: model.isSignedIn ? "View" : "")
                }
                .padding(10)
                .roundedBorder()

                // Footer
                PreferencePaneSection {
                    TextMenuItemHeader(text: "Questions about Privacy Pro?")
                    HStack(alignment: .top, spacing: 6) {
                        TextMenuItemCaption(text: "Visit our Privacy Pro help pages for answers to frequently asked questions.")
                        Button("View FAQs") { }
                    }
                }
            }
        }
    }

    public struct HeaderView: View {
        public var title: String
        public var description: String
        public var button1Name: String
        public var button2Name: String

        public init(title: String, description: String, button1Name: String, button2Name: String) {
            self.title = title
            self.description = description
            self.button1Name = button1Name
            self.button2Name = button2Name
        }

        public var body: some View {
            HStack(alignment: .top) {
                Image("SubscriptionIcon")
                    .padding(4)
                    .background(Color.black.opacity(0.06))
                    .cornerRadius(4)
                VStack(alignment: .leading, spacing: 8) {
                    TextMenuItemHeader(text: title)
                    TextMenuItemCaption(text: description)
                    HStack {
                        Button(button1Name) { }
                            .buttonStyle(DefaultActionButtonStyle(enabled: true))
                        Button(button2Name) { }
                    }
                    .padding(.top, 10)
                }
                Spacer()
            }
            .padding(.vertical, 10)
        }
    }

    public struct HeaderActiveView: View {
        public var title: String
        public var description: String
        public var button1Name: String
        public var button2Name: String

        public init(title: String, description: String, button1Name: String, button2Name: String) {
            self.title = title
            self.description = description
            self.button1Name = button1Name
            self.button2Name = button2Name
        }

        public var body: some View {
            HStack(alignment: .top) {
                Image("SubscriptionIcon")
                    .padding(4)
                    .background(Color.black.opacity(0.06))
                    .cornerRadius(4)
                VStack(alignment: .leading, spacing: 8) {
                    TextMenuItemHeader(text: title)
                    TextMenuItemCaption(text: description)
                    HStack {
                        Button(button1Name) { }

                        if #available(macOS 11.0, *) {

                            Menu {
                                Button("Change Plan or Billing...", action: {})
                                Button("Remove From This Device...", action: {})
                            } label: {
                                Text(button2Name)
                            }
                            .fixedSize()

                        }
                    }
                    .padding(.top, 10)
                }
                Spacer()
            }
            .padding(.vertical, 10)
        }
    }

    public struct SectionView: View {
        public var title: String
        public var description: String
        public var buttonName: String

        public init(title: String, description: String, buttonName: String) {
            self.title = title
            self.description = description
            self.buttonName = buttonName
        }

        public var body: some View {
            VStack(alignment: .center) {
                VStack {
                    HStack(alignment: .center, spacing: 8) {
                        Image("SubscriptionIcon")
                            .padding(4)
                            .background(Color.black.opacity(0.06))
                            .cornerRadius(4)

                        VStack (alignment: .leading) {
                            TextMenuItemCaption(text: title)
                            TextMenuItemCaption(text: description)
                                .font(Preferences.Const.Fonts.preferencePaneDisclaimer)
                        }

                        if !buttonName.isEmpty {
                            Button(buttonName) { }
                        }
                    }
                }
            }
            .padding(.vertical, 7)
        }
    }

    @available(macOS 12.0, *)
    struct SheetView: View {
        @Environment(\.dismiss) var dismiss

        let items = [MenuItem(name: "Apple ID", image: "", description: "Your subscription is automatically available on any device signed in to the same Apple ID."),
                     MenuItem(name: "Email", image: "", description: "Use your email to access your subscription on this device"),
                     MenuItem(name: "Sync", image: "", description: "DuckDuckPro is automatically available on your Synced devices. Manage your synced devices in Sync settings.")]
        @State private var selection: Set<MenuItem> = []

        @State private var selected: String = ""

        var body: some View {
            Button("X") {
                dismiss()
            }

            VStack {
                Text("Activate your subscription on this device")
                    .font(.title)
                Text("Access your Privacy Pro subscription on this device via Sync, Apple ID or an email address.")

                VStack {
                    ForEach(items) { item in
                        PlaceView(name: item.name, description: item.description, isExpanded: self.selection.contains(item))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                self.selectDeselect(item)
                            }

                        if items.last != item {
                            Divider()
                        }
                    }
                }
                .frame(minWidth: 440)
                .padding(10)
                .roundedBorder()
                .animation(.easeOut(duration: 2.3))

                Spacer()
            }
            .padding()
            .frame(width: 480, height: 450)
        }

        private func selectDeselect(_ item: MenuItem) {
            if selection.contains(item) {
                selection.remove(item)
            } else {
                selection.removeAll()
                selection.insert(item)
            }
        }
    }

    struct MenuItem: Identifiable, Hashable {
        var id = UUID()
        var name: String
        var image: String
        var description: String
    }

    struct PlaceView: View {
        let name: String
        let description: String
        let isExpanded: Bool

        @State var fullHeight: CGFloat = 0.0

        var body: some View {
            VStack(alignment: .leading) {

                HStack(alignment: .center, spacing: 8) {
                    Image("SubscriptionIcon")
                        .padding(4)
                        .background(Color.black.opacity(0.06))
                        .cornerRadius(4)

                    TextMenuItemCaption(text: name)

                    Spacer()
                        .contentShape(Rectangle())

                    if #available(macOS 11.0, *) {
                        Image(systemName: "chevron.down")
                            .rotationEffect(Angle(degrees: isExpanded ? -180 : 0))
                    }
                }
                .drawingGroup()

                VStack(alignment: .leading) {
                    TextMenuItemCaption(text: description)
                        .font(Preferences.Const.Fonts.preferencePaneDisclaimer)

                    Button("Action") { }
                        .fixedSize()
                        .frame(alignment: .top)
                        .transaction { t in
                            t.animation = nil
                        }
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear.onAppear {
                            fullHeight = proxy.size.height
                            print("Height = \(fullHeight)")
                        }
                    }
                )
                .transaction { t in
                    t.animation = nil
                }
                .frame(maxHeight: isExpanded ? fullHeight : 0, alignment: .top)
                .clipped()
                .opacity(isExpanded ? 1.0 : 0.0)
            }
        }
    }
}
