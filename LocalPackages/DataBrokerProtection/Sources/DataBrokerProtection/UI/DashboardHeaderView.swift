//
//  DashboardHeaderView.swift
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

private enum Constants {
    static let heroBottomPadding: CGFloat = 16
    static let titleSubtitlePadding: CGFloat = 5
}

@available(macOS 11.0, *)
public struct DashboardHeaderView: View {
    public init() { }
    public var body: some View {
        ZStack {
            Image("header-background", bundle: .module).resizable()

            VStack (spacing: 0) {
                HStack {
                    Spacer()
                    CTAHeaderView()
                }
                HeaderTitleView()
                Spacer()
            }
        }
    }
}

@available(macOS 11.0, *)
private struct HeaderTitleView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image("header-hero", bundle: .module)
                .padding(.bottom, Constants.heroBottomPadding)
            VStack (spacing: Constants.titleSubtitlePadding) {
                Text("Data Broker Protection")
                    .font(.title)
                    .bold()
                    .foregroundColor(.black)

                Text("Full scan in progress...")
                    .font(.body)
                    .foregroundColor(.black)
            }
        }
    }
}

@available(macOS 11.0, *)
private struct CTAHeaderView: View {
    var body: some View {
        HStack {
            Button {
                print("FAQ")
            } label: {
                Text("FAQs")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.black)

            Button {
                print("Edit Profile")
            } label: {
                HStack {
                    Image(systemName: "person")
                    Text("Edit Profile")
                }
                .frame(maxWidth: 110, maxHeight: 26)
            }.buttonStyle(CTAButtonStyle())
        }
    }
}

@available(macOS 11.0, *)
struct DashboardHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardHeaderView()
            .frame(width: 1000, height: 300)
    }
}
