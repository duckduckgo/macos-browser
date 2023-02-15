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
import Combine

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
    @Binding var popoverHeight: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0, content: content)
            .frame(maxHeight: popoverHeight)
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { geometry in
                /// Since .onAppear is only called once, we'll use a different view for the collapsed and expanded states.
                /// so that the proper height is calculated for both.
                Color.clear.onReceive(Just(popoverHeight)) { _ in
                    if popoverHeight == .infinity {
                        popoverHeight = geometry.size.height
                    }
                }
            })
            .background(VisualEffectView(material: .windowBackground, blendingMode: .behindWindow).edgesIgnoringSafeArea(.all))
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
    static let link = Double(1)
    static let title = Double(1)
}

fileprivate extension View {
    func applyTimerAttributes() -> some View {
        opacity(Opacity.content)
            .font(.NetworkProtection.content.monospacedDigit())
    }

    func applyContentAttributes() -> some View {
        opacity(Opacity.content)
            .font(.NetworkProtection.content)
    }

    func applyLinkAttributes() -> some View {
        opacity(Opacity.link)
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
    
    @State private var popoverHeight = CGFloat.infinity

    // MARK: - Initializers

    init(model: Model = Model()) {
        self.model = model
    }

    // MARK: - View Contents

    public var body: some View {
        PopoverHeightFixer(popoverHeight: $popoverHeight) {
            headerView()

            if let healthWarning = model.issueDescription {
                connectionHealthWarningView(message: healthWarning).onAppear {
                    popoverHeight = .infinity
                }
                .onDisappear {
                    popoverHeight = .infinity
                }
            }

            VStack(spacing: 0) {
                featureView()
                detailsView()
            }
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 4, trailing: 8))
        }
        .frame(maxWidth: 369)
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

    private func connectionHealthWarningView(message: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image("WarningColored")

                /// Text elements in SwiftUI don't expand horizontally more than needed, so we're adding an "optional" spacer at the end so that
                /// the alert bubble won't shrink if there's not enough text.
                HStack(spacing: 0) {
                    Text(message)
                    Spacer()
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color("AlertBubbleBackground")))
        }
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 4, trailing: 8))
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
                statusView().onAppear {
                    popoverHeight = .infinity
                }
                .onDisappear {
                    popoverHeight = .infinity
                }
            }

            Text(UserText.networkProtectionStatusViewBetaWarning)
                .opacity(Opacity.content)
                .fixedSize()

            HStack(spacing: 0) {
                Text(UserText.networkProtectionStatusViewShareFeedbackPrefix)
                    .applyContentAttributes()
                    .fixedSize()

                TextButton(UserText.networkProtectionStatusViewShareFeedback) {
                    model.shareFeedback()
                }.applyLinkAttributes()
                    .fixedSize()
                    .buttonStyle(PlainButtonStyle())

                Text(UserText.networkProtectionStatusViewShareFeedbackSuffix)
                    .applyContentAttributes()
                    .fixedSize()
            }
            .padding([.bottom], 18)
        }
        .padding(EdgeInsets(top: 12, leading: 8, bottom: 0, trailing: 8))
    }

    /// Connection status: server IP address and location
    ///
    private func statusView() -> some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    .applyTimerAttributes()
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
