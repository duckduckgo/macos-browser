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

struct NoResultsFoundView: View {
    let buttonClicked: () -> Void

    private let items: [RowItem] = [
        RowItem(imageName: "checkmark.circle", text: "Include your middle name"),
        RowItem(imageName: "checkmark.circle", text: "Add other names, such as maiden name or nicknames"),
        RowItem(imageName: "checkmark.circle", text: "Include previous home addresses")]

    var body: some View {
        VStack {
            HeaderView(title: "No Results Found!",
                       subtitle: "We were unable to find any matches with the information you provided.",
                       iconName: "clock.fill",
                       iconColor: .yellow)
                .padding(.bottom, 30)

            InfoView(buttonClicked: buttonClicked,
                     rowItems: items)
        }
    }
}

private struct InfoView: View {
    let buttonClicked: () -> Void

    let rowItems: [RowItem]

    var body: some View {
        VStack {
            Text("Try adding more info to your profile.")
                .font(.title)
                .bold()

            VStack(alignment: .leading, spacing: 16) {
                ForEach(rowItems) { item in
                    HStack {
                        Image(systemName: item.imageName)
                        Text(item.text)
                    }
                }
            }.padding()

            CTAButton(title: "Edit Profile",
                      buttonClicked: buttonClicked)

        }.padding(40)
            .frame(width: 600, alignment: .center)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .inset(by: 0.5)
                    .stroke(Color.secondary, lineWidth: 1)
                    .opacity(0.3)
            )
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
                .frame(width: 150, height: 44)
        }
        .buttonStyle(CTAButtonStyle())
    }
}

private struct RowItem: Identifiable {
    let id = UUID()
    let imageName: String
    let text: String
}

struct NoResultsFoundView_Previews: PreviewProvider {
    static var previews: some View {

        NoResultsFoundView(buttonClicked: {})
            .padding(40)
    }
}
