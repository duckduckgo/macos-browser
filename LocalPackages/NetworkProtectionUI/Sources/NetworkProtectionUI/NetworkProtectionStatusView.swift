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
import NetworkProtection

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
    }
}

fileprivate extension Font {
    enum NetworkProtection {
        static var title: Font {
            .system(size: 15, weight: .semibold, design: .default)
        }

        static var sectionHeader: Font {
            .system(size: 12, weight: .semibold, design: .default)
        }

        static var content: Font {
            .system(size: 13, weight: .regular, design: .default)
        }
    }
}

private enum Opacity {
    static let content = Double(0.58)
    static let label = Double(0.84)
    static let description = Double(0.9)
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

    func applyDescriptionAttributes() -> some View {
        opacity(Opacity.description)
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

    @Environment(\.dismiss) private var dismiss

    // MARK: - Model

    /// The view model that this instance will use.
    ///
    @ObservedObject var model: Model

    @State private var popoverHeight = CGFloat.infinity

    // MARK: - Initializers

    public init(model: Model) {
        self.model = model
    }

    // MARK: - View Contents

    public var body: some View {
        PopoverHeightFixer(popoverHeight: $popoverHeight) {
            VStack(spacing: 0) {
                if let healthWarning = model.issueDescription {
                    connectionHealthWarningView(message: healthWarning).onAppear {
                        popoverHeight = .infinity
                    }
                    .onDisappear {
                        popoverHeight = .infinity
                    }
                }

                headerView()
                featureToggleRow()

                Divider()
                    .padding(EdgeInsets(top: 5, leading: 9, bottom: 5, trailing: 9))

                if model.showServerDetails {
                    connectionStatusView().onAppear {
                        popoverHeight = .infinity
                    }
                    .onDisappear {
                        popoverHeight = .infinity
                    }
                }

                bottomMenuView()
            }
            .padding(EdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
        }
        .frame(maxWidth: 350)
    }

    // MARK: - Composite Views

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
    private func headerView() -> some View {
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
                .applyDescriptionAttributes()
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
        }
    }

    /// Connection status: server IP address and location
    ///
    private func connectionStatusView() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(UserText.networkProtectionStatusViewConnDetails)
                .font(.NetworkProtection.sectionHeader)
                .padding(EdgeInsets(top: 6, leading: 9, bottom: 6, trailing: 9))

            connectionStatusRow(icon: .serverLocationIcon,
                                title: UserText.networkProtectionStatusViewLocation,
                                details: model.serverLocation)
            connectionStatusRow(icon: .ipAddressIcon,
                                title: UserText.networkProtectionStatusViewIPAddress,
                                details: model.serverAddress)

            dividerRow()
        }
    }

    private func bottomMenuView() -> some View {
        VStack(spacing: 0) {
            MenuItemButton("Share feedback...") {
                model.shareFeedback()
                dismiss()
            }

            if model.showLaunchBrowserMenuItem {
                MenuItemButton("Open DuckDuckGo...") {
                    model.launchBrowser()
                    dismiss()
                }
            }
        }
    }

    // MARK: - Rows

    private func dividerRow() -> some View {
        Divider()
            .padding(EdgeInsets(top: 5, leading: 9, bottom: 5, trailing: 9))
    }

    private func featureToggleRow() -> some View {
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
        .padding(EdgeInsets(top: 3, leading: 9, bottom: 3, trailing: 9))
    }

    private func connectionStatusRow(icon: NetworkProtectionAsset, title: String, details: String) -> some View {
        HStack(spacing: 0) {
            Image(icon)
                .padding([.trailing], 8)

            Text(title)
                .opacity(Opacity.label)
                .fixedSize()

            Spacer(minLength: 16)

            Text(details)
                .opacity(Opacity.content)
                .fixedSize()
        }
        .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 9))
    }
}

struct NetworkProtectionStatusView_Previews: PreviewProvider {

    private class PreviewController: NetworkProtection.TunnelController {
        func isConnected() async -> Bool {
            false
        }

        func start() async throws {
            print("Preview controller started")
        }

        func stop() async throws {
            print("Preview controller stopped")
        }
    }

    /// Convenience reporter for SwiftUI preview
    ///
    private final class PreviewNetworkProtectionStatusReporter: NetworkProtectionStatusReporter {
        let statusPublisher = CurrentValueSubject<ConnectionStatus, Never>(.connected(connectedDate: Date()))
        let connectivityIssuesPublisher = CurrentValueSubject<Bool, Never>(false)
        let serverInfoPublisher = CurrentValueSubject<NetworkProtectionStatusServerInfo, Never>(NetworkProtectionStatusServerInfo(serverLocation: "Los Angeles, USA", serverAddress: "127.0.0.1"))
        let connectionErrorPublisher = CurrentValueSubject<String?, Never>(nil)
        let controllerErrorMessagePublisher = CurrentValueSubject<String?, Never>(nil)

        func forceRefresh() {
            // No-op
        }
    }

    static var previews: some View {
        let statusReporter = PreviewNetworkProtectionStatusReporter()
        let model = NetworkProtectionStatusView.Model(controller: PreviewController(),
                                                      showLaunchBrowserMenuItem: true,
                                                      statusReporter: statusReporter)

        NetworkProtectionStatusView(model: model)
    }
}
