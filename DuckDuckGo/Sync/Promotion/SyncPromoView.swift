//
//  SyncPromoView.swift
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
import PixelKit

struct SyncPromoView: View {

    enum Layout {
        case compact
        case horizontal
        case vertical
    }

    @State private var isHovering = false

    let viewModel: SyncPromoViewModel
    var layout: Layout = .compact

    var body: some View {
        Group {
            switch layout {
            case .compact:
                compactLayoutView
            case .horizontal:
                horizontalLayoutView
            case .vertical:
                verticalLayoutView
            }
        }
        .onAppear {
            PixelKit.fire(SyncPromoPixelKitEvent.syncPromoDisplayed.withoutMacPrefix, withAdditionalParameters: ["source": viewModel.touchpointType.rawValue])
        }
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            VStack {
                HomePage.Views.CloseButton(icon: .close, size: 16) {
                    dismissAction()
                }
                .padding(6)

                Spacer()
            }
        }
    }

    private var backgroundRectangle: some View {
        RoundedRectangle(cornerRadius: 8)
            .foregroundColor(isHovering ? Color.black.opacity(0.06) : Color.blackWhite3)
    }

    private var image: some View {
        Image(viewModel.image)
            .resizable()
            .frame(width: 48, height: 48)
    }

    private var title: some View {
        Text(viewModel.title)
            .font(.system(size: layout == .vertical ? 15 : 13).bold())
            .multilineTextAlignment(layout == .vertical ? .center : .leading)
            .multilineText()
    }

    private var subtitle: some View {
        Text(viewModel.subtitle)
            .multilineTextAlignment(layout == .vertical ? .center : .leading)
            .multilineText()
    }

    private var compactLayoutView: some View {
        ZStack {
            backgroundRectangle

            HStack(alignment: .top) {
                image
                    .padding(.top, 14)

                VStack(alignment: .leading) {

                    title

                    subtitle
                        .padding(.top, 1)
                        .padding(.bottom, 6)

                    HStack {
                        Button(viewModel.secondaryButtonTitle) {
                            dismissAction()
                        }
                        .buttonStyle(DismissActionButtonStyle())

                        Button(viewModel.primaryButtonTitle) {
                            primaryAction()
                        }
                        .buttonStyle(DefaultActionButtonStyle(enabled: true))
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 14)
                .padding(.trailing, 40)
            }
            .padding(.leading, 8)
        }
    }

    private var horizontalLayoutView: some View {
        ZStack {
            backgroundRectangle

            HStack(alignment: .center) {
                image

                VStack(alignment: .leading) {

                    title

                    subtitle
                        .padding(.bottom, 2)
                }

                Spacer()

                Button(viewModel.primaryButtonTitle) {
                    primaryAction()
                }
                .buttonStyle(DismissActionButtonStyle())
                .padding(.trailing, 32)
            }
            .padding(.leading, 8)
            .padding(.vertical, 8)

            closeButton
        }
        .onHover { isHovering in
            self.isHovering = isHovering
        }
    }

    private var verticalLayoutView: some View {
        VStack(alignment: .center, spacing: 16) {

            Image(.syncStart128)
                .resizable()
                .frame(width: 96, height: 72)

            VStack(spacing: 8) {
                title

                subtitle
            }
            .frame(width: 192)

            HStack {

                Button {
                    dismissAction()
                } label: {
                    Text(viewModel.secondaryButtonTitle)
                        .multilineTextAlignment(.center)
                        .padding(.top, 5)
                        .padding(.bottom, 5)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.blackWhite10))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    primaryAction()
                } label: {
                    Text(viewModel.primaryButtonTitle)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 5)
                        .padding(.bottom, 5)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.controlAccentColor))
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(width: 224)
        .padding(.top, 70)
    }

    private func primaryAction() {
        viewModel.primaryButtonAction?()
        PixelKit.fire(SyncPromoPixelKitEvent.syncPromoConfirmed.withoutMacPrefix, withAdditionalParameters: ["source": viewModel.touchpointType.rawValue])
    }

    private func dismissAction() {
        viewModel.dismissButtonAction?()
        PixelKit.fire(SyncPromoPixelKitEvent.syncPromoDismissed.withoutMacPrefix, withAdditionalParameters: ["source": viewModel.touchpointType.rawValue])
    }
}

#Preview("Compact") {
    SyncPromoView(viewModel: SyncPromoViewModel(touchpointType: .bookmarks, primaryButtonAction: {}, dismissButtonAction: {}),
                  layout: .compact)
        .frame(height: 115)
}

#Preview("Horizontal") {
    SyncPromoView(viewModel: SyncPromoViewModel(touchpointType: .bookmarks, primaryButtonAction: {}, dismissButtonAction: {}),
                  layout: .horizontal)
        .frame(height: 80)
}

#Preview("Vertical") {
    SyncPromoView(viewModel: SyncPromoViewModel(touchpointType: .bookmarks, primaryButtonAction: {}, dismissButtonAction: {}),
                  layout: .vertical)
        .frame(height: 300)
}
