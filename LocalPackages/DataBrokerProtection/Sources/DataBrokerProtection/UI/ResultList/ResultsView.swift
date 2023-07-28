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
    @ObservedObject var viewModel: ResultsViewModel

    var body: some View {
        VStack(spacing: Const.verticalSpacing) {
            if !viewModel.pendingProfiles.isEmpty {
                PendingProfilesView(profiles: viewModel.pendingProfiles)
            }

            if !viewModel.removedProfiles.isEmpty {
                RemovedProfilesView(profiles: viewModel.removedProfiles)
            }
        }
    }
}

@available(macOS 11.0, *)
private struct RemovedProfilesView: View {
    let profiles: [ResultsViewModel.RemovedProfile]

    var body: some View {
        VStack(spacing: Const.verticalSpacing) {
            HeaderView(title: "\(profiles.count) Profiles Removed",
                       subtitle: "We will re-scan these sites on a regular basis and send removal requests if your data resurfaces.",
                       iconName: "checkmark.circle.fill",
                       iconColor: .green)
            VStack {
                ForEach(profiles) { profile in
                    RemovedProfileRow(removedProfile: profile)
                        .padding()
                    Divider()
                        .foregroundColor(Color.secondary)

                }
            }.listBackgroundStyle()
        }
    }
}

@available(macOS 11.0, *)
private struct PendingProfilesView: View {
    let profiles: [ResultsViewModel.PendingProfile]

    var body: some View {
        VStack(spacing: Const.verticalSpacing) {
            HeaderView(title: "\(profiles.count) Profiles Pending Removal",
                       subtitle: "We automatically requested these sites to remove your data. This can take 2–3 weeks.",
                       iconName: "clock.fill",
                       iconColor: .yellow)

            VStack {
                ForEach(profiles) { profile in
                    PendingProfileRow(pendingProfile: profile)
                        .padding()

                    Divider()
                        .foregroundColor(Color.secondary)
                }
            }.listBackgroundStyle()
                .transition(.opacity)
        }
    }
}

@available(macOS 11.0, *)
private struct RemovedProfileRow: View {
    let removedProfile: ResultsViewModel.RemovedProfile

    var body: some View {
        HStack {
            Label {
                Text(removedProfile.dataBroker)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            Spacer()

            HStack {
                Text("Re-scan scheduled")
                Text("-")
                Text(removedProfile.formattedDate)
            }
        }
    }
}

@available(macOS 11.0, *)
private struct PendingProfileRow: View {
    let pendingProfile: ResultsViewModel.PendingProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label {
                    Text(pendingProfile.dataBroker)
                } icon: {
                    Image(systemName: pendingProfile.hasError ? "exclamationmark.triangle.fill" : "clock.fill")
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
                    Text(pendingProfile.address)
                        .lineLimit(1)
                        .frame(width: 180, alignment: .leading)

                } icon: {
                    Image(systemName: "house")
                }
            }
            if pendingProfile.hasError {
                Text("\(Text(pendingProfile.error ?? "unknown").bold()) - \(pendingProfile.errorDescription ?? "unkonwn")")
                    .layoutPriority(1)
                    .padding(.leading, 24)
            }
        }
    }
}

// MARK: - Constants
private enum Const {
    static let verticalSpacing: CGFloat = 40
}

// MARK: - Modifier
private struct ListBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color("list-background-color", bundle: .module))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
    }
}

private extension View {
    func listBackgroundStyle() -> some View {
        modifier(ListBackground())
    }
}

// MARK: - Preview
@available(macOS 11.0, *)
struct ResultsView_Previews: PreviewProvider {
    static var previews: some View {
        ResultsView(viewModel: ResultsViewModel()).frame(height: 700)
            .padding()
    }
}
