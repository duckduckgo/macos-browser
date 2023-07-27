//
//  ResultsView.swift
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
struct ResultsView: View {
    var body: some View {
        VStack(spacing: 40) {
            PendingProfilesView()
            RemovedProfilesView()
        }
    }
}

@available(macOS 11.0, *)
private struct RemovedProfilesView: View {
    var body: some View {
        VStack(spacing: 40) {
            HeaderView(title: "10 Profiles Removed",
                       subtitle: "We will re-scan these sites on a regular basis and send removal requests if your data resurfaces.",
                       iconName: "checkmark.circle.fill",
                       iconColor: .green)

            VStack (spacing: 10) {
                RemovedProfileRow()
                RemovedProfileRow()
                RemovedProfileRow()
                RemovedProfileRow()
            }
        }
    }
}

@available(macOS 11.0, *)
private struct PendingProfilesView: View {
    var body: some View {
        VStack(spacing: 40) {
            HeaderView(title: "3 Profiles Pending Removal",
                       subtitle: "We automatically requested these sites to remove your data. This can take 2–3 weeks.",
                       iconName: "clock.fill",
                       iconColor: .yellow)

            VStack {
                PendingProfileRow()
                    .padding()
                Divider()
                    .foregroundColor(Color.secondary)

                PendingProfileRow()
                    .padding()

                Divider()
                    .foregroundColor(Color.secondary)

                PendingProfileRow()
                    .padding()

                Divider()
                    .foregroundColor(Color.secondary)
            }
            .background(Color("background-color", bundle: .module))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

@available(macOS 11.0, *)
private struct RemovedProfileRow: View {
    var body: some View {
        HStack {
            Label {
                Text("Verecor")
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            Spacer()

            HStack {
                Text("Re-scan scheduled")
                Text("-")
                Text("15 Jun 23")
            }
        }
    }
}

@available(macOS 11.0, *)
private struct PendingProfileRow: View {
    let hasError = true

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Label {
                    Text("Verecor")
                } icon: {
                    Image(systemName: hasError ? "exclamationmark.triangle.fill" : "clock.fill")
                        .foregroundColor(.yellow)
                }
                Spacer()
                Label {
                    Text("John Smith")
                } icon: {
                    Image(systemName: "person")
                }

                Spacer()

                Label {
                    Text("4564 N Isle Royale St, Rocklin, CA ")
                        .lineLimit(1)
                        .frame(width: 180)
                } icon: {
                    Image(systemName: "house")
                }
            }
            if hasError {

                Text("\(Text("Error 123").bold()) - Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
                    .layoutPriority(1)
            }
        }
    }
}

@available(macOS 11.0, *)
struct ResultsView_Previews: PreviewProvider {
    static var previews: some View {
        ResultsView().frame(height: 700)
            .padding()
    }
}
