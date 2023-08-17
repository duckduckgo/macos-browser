//
//  GettingStartedView.swift
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

@available(macOS 11.0, *)
struct GettingStartedView: View {
    let buttonClicked: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: Constants.ContainerView.verticalSpacing) {
            TitleView(title: "Getting Started",
                      subtitle: "Data brokers and people-search sites publish personal info online.\nDiscover where you’re exposed and automatically remove your data.")
            DividerView()

            BodyView(rowItems: [
                RowItem(imageName: "person.badge.plus",
                        title: "Personal Information",
                        subtitle: "Your info is required for us to find matching profiles within data broker sites."),

                RowItem(imageName: "externaldrive.badge.person.crop",
                        title: "We Don’t Store Your Data",
                        subtitle: "All your information is stored on-device."),

                RowItem(imageName: "globe.americas",
                        title: "United States Only",
                        subtitle: "Data brokers we cover target people with US addresses.")
            ])

            CTAButton(title: "Get Started", buttonClicked: buttonClicked)
        }
        .shadedBorderedPanel(backgroundColor: Color("modal-background-color", bundle: .module))
    }
}

private struct CTAButton: View {
    let title: String
    let buttonClicked: () -> Void

    var body: some View {
        Button {
            buttonClicked()
        } label: {
            Text(title)
                .bold()
                .frame(width: Constants.CTA.width, height: Constants.CTA.height)
        }
        .buttonStyle(CTAButtonStyle())
    }
}

private struct TitleView: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .center, spacing: Constants.titleViewSpacing) {
            Text(title)
                .font(.title)
                .bold()

            Text(subtitle)
                .frame(minHeight: 32)
                .foregroundColor(.secondary)
        }
    }
}

private struct DividerView: View {
    var body: some View {
        Rectangle()
            .foregroundColor(.clear)
            .frame(width: Constants.Divider.width, height: Constants.Divider.height)
            .background(
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: .primary.opacity(0.16), location: 0.00),
                        Gradient.Stop(color: .primary.opacity(0.7), location: 0.50),
                        Gradient.Stop(color: .primary.opacity(0.16), location: 1.00)
                    ],
                    startPoint: UnitPoint(x: 1, y: 0),
                    endPoint: UnitPoint(x: 0, y: 0)
                )
            )
    }
}

private struct RowItem: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
    let subtitle: String
}

@available(macOS 11.0, *)
private struct BodyView: View {
    let rowItems: [RowItem]

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.bodyViewSpacing) {
            ForEach(rowItems) { item in
                RowItemView(item: item)
            }
        }
    }
}

@available(macOS 11.0, *)
private struct RowItemView: View {
    let item: RowItem

    var body: some View {
        HStack(alignment: .top, spacing: Constants.RowItem.horizontalSpacing) {
            Image(systemName: item.imageName)
                .resizable()
                .frame(width: Constants.RowItem.imageSize.width, height: Constants.RowItem.imageSize.height)
            VStack(alignment: .leading, spacing: Constants.RowItem.textVerticalSpacing) {
                Text(item.title)
                    .font(.title2)
                Text(item.subtitle)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private enum Constants {
    enum CTA {
        static let width: CGFloat = 440
        static let height: CGFloat = 44
    }

    enum Divider {
        static let width: CGFloat = 440
        static let height: CGFloat = 2
    }

    enum RowItem {
        static let horizontalSpacing: CGFloat = 16
        static let textVerticalSpacing: CGFloat = 2
        static let imageSize = CGSize(width: 24, height: 24)
    }

    enum ContainerView {
        static let padding: CGFloat = 48
        static let cornerRadius: CGFloat = 16
        static let verticalSpacing: CGFloat = 24
    }

    static let bodyViewSpacing: CGFloat = 16
    static let titleViewSpacing: CGFloat = 16
}

@available(macOS 11.0, *)
struct GettingStartedView_Previews: PreviewProvider {
    static var previews: some View {
        GettingStartedView(buttonClicked: {}).frame(width: 600, height: 400)
    }
}
