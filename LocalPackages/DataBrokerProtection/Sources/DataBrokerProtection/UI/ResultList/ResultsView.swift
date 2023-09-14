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

struct ResultsView: View {
    @ObservedObject var viewModel: ResultsViewModel

    var body: some View {
        VStack(spacing: Const.verticalSpacing) {
            if viewModel.isLoading && viewModel.pendingProfiles.isEmpty && viewModel.removedProfiles.isEmpty {
                HeaderView(title: "We are crunching your local data ...",
                           subtitle: "The list of profiles matches will appear soon",
                           iconName: "clock.fill",
                           iconColor: .gray)
                ProgressView()
            }

            if !viewModel.pendingProfiles.isEmpty {
                PendingProfilesView(profiles: viewModel.pendingProfiles)
            }

            if !viewModel.removedProfiles.isEmpty {
                RemovedProfilesView(profiles: viewModel.removedProfiles)
            }
        }
    }
}

private struct RemovedProfilesView: View {
    let profiles: [ResultsViewModel.RemovedProfile]

    var body: some View {
        VStack(spacing: Const.verticalSpacing) {
            HeaderView(title: "\(profiles.count) Profiles Removed",
                       subtitle: "We will re-scan these sites on a regular basis and send removal requests if your data resurfaces.",
                       iconName: "checkmark.circle.fill",
                       iconColor: .green)
            .textAnimationDisabled(true)

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

private struct PendingProfilesView: View {
    let profiles: [ResultsViewModel.PendingProfile]

    var body: some View {
        VStack(spacing: Const.verticalSpacing) {
            HeaderView(title: "\(profiles.count) Profiles Pending Removal",
                       subtitle: "We automatically requested these sites to remove your data. This can take 2–3 weeks.",
                       iconName: "clock.fill",
                       iconColor: .yellow)
            .textAnimationDisabled(true)

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

private struct PendingProfileRow: View {
    let pendingProfile: ResultsViewModel.PendingProfile
    @State private var showModal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                Button {
                    showModal = true
                } label: {
                    Label {
                        Text(pendingProfile.dataBroker)
                            .frame(width: 220, alignment: .leading)

                    } icon: {
                        Image(systemName: pendingProfile.hasError ? "exclamationmark.triangle.fill" : "clock.fill")
                            .foregroundColor(.yellow)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .sheet(isPresented: $showModal) {

                    DebugModalView(optOutOperationData: pendingProfile.operationData,
                                   showingModal: $showModal)
                }

                Spacer()

                Label {
                    Text(pendingProfile.profileWithAge)
                        .lineLimit(1)
                        .frame(width: 180, alignment: .leading)

                } icon: {
                    Image(systemName: "person")
                }

                Spacer()

                Label {
                    VStack (alignment: .leading) {
                        ForEach(pendingProfile.relatives, id: \.self) {  relative in
                            Text(relative)
                                .lineLimit(1)
                        }
                    }
                    .frame(width: 180, alignment: .leading)

                } icon: {
                    Image(systemName: "person.3")
                }

                Spacer()

                Label {
                    VStack (alignment: .leading) {
                        ForEach(pendingProfile.addresses, id: \.self) {  address in
                            Text(address)
                                .lineLimit(1)
                        }
                    }
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

// MARK: - DebugModalView

private struct DebugModalView: View {
    let optOutOperationData: OptOutOperationData
    @Binding var showingModal: Bool

    var sortedEvents: [HistoryEvent] {
        optOutOperationData.historyEvents.sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading) {
            ScrollView {
                ForEach(sortedEvents) { event in
                    VStack {
                        Text("Event \(labelForEvent(event))")
                        Text("Date: \(formatDate(event.date))")
                        Divider()
                    }
                }
            }.frame(width: 400, height: 600)

            if let date = optOutOperationData.preferredRunDate {
                Text("Preferred Run Date \(formatDate(date))")
            } else {
                Text("Preferred Run Date not set")
            }

            Button {
                showingModal = false
            } label: {
                Text("Close")
            }

        }.padding()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func labelForEvent(_ event: HistoryEvent) -> String {
        switch event.type {
        case .noMatchFound:
            return "No match found"
        case .matchesFound:
            return "Matches found"
        case .error(error: let error):
            return labelForErrorEvent(error)
        case .optOutStarted:
            return "Opt-out started for extracted profile with id: \(event.extractedProfileId!)"
        case .optOutRequested:
            return "Opt-out requested for extracted profile with id: \(event.extractedProfileId!)"
        case .optOutConfirmed:
            return "Opt-out confirmed for extracted profile with id: \(event.extractedProfileId!)"
        case .scanStarted:
            return "Scan Started"
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func labelForErrorEvent(_ error: DataBrokerProtectionError) -> String {
        switch error {
        case .malformedURL:
            return "malformedURL"
        case .noActionFound:
            return "noActionFound"
        case .actionFailed(actionID: let actionID, message: let message):
            return "actionFailed \(actionID) \(message)"
        case .parsingErrorObjectFailed:
            return "parsingErrorObjectFailed"
        case .unknownMethodName:
            return "unknownMethodName"
        case .userScriptMessageBrokerNotSet:
            return "userScriptMessageBrokerNotSet"
        case .unknown(let value):
            return "unknown \(value)"
        case .unrecoverableError:
            return "unrecoverableError"
        case .noOptOutStep:
            return "noOptOutStep"
        case .captchaServiceError(let captchaError):
            return "captchaServiceError \(captchaError)"
        case .emailError(let emailError):
            return "emailError \(String(describing: emailError))"
        case .cancelled:
            return "Cancelled"
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
            .background(Color("modal-background-color", bundle: .module))
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
struct ResultsView_Previews: PreviewProvider {
    static var previews: some View {
        let dataManager = DataBrokerProtectionDataManager()
        let resultsViewModel = ResultsViewModel(dataManager: dataManager)

        ResultsView(viewModel: resultsViewModel)
            .frame(height: 700)
            .padding()
    }
}

extension View {
    @ViewBuilder
    func textAnimationDisabled(_ disabled: Bool = true) -> some View {
        if #available(macOS 13.0, *) {
            contentTransition(disabled ? .identity : .opacity)
        } else {
            self
        }
    }
}
