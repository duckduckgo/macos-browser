//
//  NetworkProtectionStatusView.swift
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

/// This view helps us fix the height of a view that's meant to be shown inside a `NSHostingView`.
///
/// It seems the `NSHostingView` uses the max height of the SwiftUI View for its own height, which for multi-line
/// `Text` views is the maximum number of lines that it could show (which makes the hosting view become huge).
/// This view updates it's max height to it's actual height after layout, meaning the hosting view will be sized correctly.
///
/// If the view supports multiple heights, you'll probably need to adapt it with a solution that's similar to the collapsed/expanded
/// solution that's included.
///
struct PopoverHeightFixer<Content: View>: View {
    var collapsed: Bool
    @State private var maxCollapsedHeight = CGFloat.infinity
    @State private var maxExpandedHeight = CGFloat.infinity

    var maxHeight: CGFloat {
        if collapsed {
            return maxCollapsedHeight
        } else {
            return maxExpandedHeight
        }
    }

    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0, content: content)
            .frame(maxHeight: maxHeight)
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { geometry in
                /// Since .onAppear is only called once, we'll use a different view for the collapsed and expanded states.
                /// so that the proper height is calculated for both.
                if collapsed {
                    Color.clear.onAppear {
                        maxCollapsedHeight = geometry.size.height
                    }
                } else {
                    Color.clear.onAppear {
                        maxExpandedHeight = geometry.size.height
                    }
                }
            })
    }
}

fileprivate extension Font {
    enum NetworkProtection {
        static var title: Font {
            .system(size: 15, weight: .semibold, design: .default)
        }

        static var sectionHeader: Font {
            .system(size: 13, weight: .semibold, design: .default)
        }

        static var content: Font {
            .system(size: 13, weight: .regular, design: .default)
        }
    }
}

private enum Opacity {
    static let content = Double(0.58)
    static let label = Double(0.84)
    static let title = Double(1)
}

fileprivate extension View {
    func applyContentAttributes() -> some View {
        opacity(Opacity.content)
            .font(.NetworkProtection.content)
    }

    func applyLabelAttributes() -> some View {
        opacity(Opacity.label)
            .font(.NetworkProtection.content)
    }

    func applyTitleAttributes() -> some View {
        opacity(Opacity.title)
            .font(.NetworkProtection.title)
    }
}

public struct NetworkProtectionStatusView: View {

    // MARK: - Model

    /// The view model that this instance will use.
    ///
    @ObservedObject var model: Model

    // MARK: - View Contents

    public var body: some View {
        PopoverHeightFixer(collapsed: !model.showServerDetails) {
            headerView()

            VStack(spacing: 0) {
                featureView()
                detailsView()
            }
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 4, trailing: 8))
        }
    }

    /// Title and divider
    ///
    private func headerView() -> some View {
        VStack(spacing: 0) {
            Text(UserText.networkProtectionStatusViewTitle)
                .applyTitleAttributes()
                .padding(12)

            Divider()
        }
    }

    /// Main image, feature ON/OFF and feature description
    ///
    private func featureView() -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Image(model.mainImageAsset)
                Spacer()
            }

            Text(model.featureStatusDescription)
                .applyTitleAttributes()
                .padding([.top], 8)

            Text(UserText.networkProtectionStatusViewFeatureDesc)
                .applyContentAttributes()
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))
        }
        .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
    }

    /// Details view: toggle, divider, server status view, beta warning.
    ///
    private func detailsView() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            featureToggle()

            Divider()
                .padding([.top, .bottom], 18)

            if model.showServerDetails {
                statusView()
            }

            Text(UserText.networkProtectionStatusViewBetaWarning)
                .opacity(Opacity.content)
                .fixedSize()
                .padding([.bottom], 18)
        }
        .padding(EdgeInsets(top: 12, leading: 8, bottom: 0, trailing: 8))
    }

    /// Connection status: server IP address and location
    ///
    private func statusView() -> some View {
        VStack(spacing: 0) {
            Text(UserText.networkProtectionStatusViewConnDetails)
                .font(.NetworkProtection.sectionHeader)
                .padding(.bottom, 18)

            serverLocationView()
            serverAddressView()
        }
    }

    // MARK: - Composite Views

    private func featureToggle() -> some View {
        Toggle(isOn: model.isRunning) {
            HStack {
                Text(UserText.networkProtectionStatusViewConnLabel)
                    .applyLabelAttributes()
                    .frame(alignment: .leading)
                    .fixedSize()

                Spacer(minLength: 16)

                Text(model.connectionStatusDescription)
                    .opacity(Opacity.content)
                    .font(.NetworkProtection.content)
                    .frame(alignment: .trailing)
                    .fixedSize()

                Spacer()
                    .frame(width: 16)
            }
        }
        .toggleStyle(.switch)
    }

    private func serverLocationView() -> some View {
        HStack(spacing: 0) {
            Image(.serverLocationIcon)
                .padding([.trailing], 8)

            Text(UserText.networkProtectionStatusViewLocation)
                .opacity(Opacity.label)
                .fixedSize()

            Spacer(minLength: 16)

            Text(model.serverLocation)
                .opacity(Opacity.content)
                .fixedSize()
        }
        .padding(.bottom, 18)
    }

    private func serverAddressView() -> some View {
        HStack(spacing: 0) {
            Image(.ipAddressIcon)
                .padding([.trailing], 8)

            Text(UserText.networkProtectionStatusViewIPAddress)
                .opacity(Opacity.label)
                .fixedSize()

            Spacer(minLength: 16)

            Text(model.serverAddress)
                .opacity(Opacity.content)
                .fixedSize()
        }
        .padding(.bottom, 18)
    }

}

struct NetworkProtectionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        NetworkProtectionStatusView(model: NetworkProtectionStatusView.Model())
    }
}
