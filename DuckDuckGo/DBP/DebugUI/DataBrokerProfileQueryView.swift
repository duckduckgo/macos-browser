//
//  DataBrokerProfileQueryView.swift
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
import DataBrokerProtection

public final class DataBrokerProfileQueryViewModel: ObservableObject, DataBrokerProtectionDataManagerDelegate {
    public func dataBrokerProtectionDataManagerDidUpdateData() {
        DispatchQueue.main.async {
            self.setupData()
        }
    }

    private let dataManager: DataBrokerProtectionDataManager
    @Published var dataInfo = [DataBrokerInfoData]()

    init(dataManager: DataBrokerProtectionDataManager) {
        self.dataManager = dataManager
        self.dataManager.delegate = self
        setupData()
    }

    private func setupData() {
        self.dataInfo = self.dataManager.fetchDataBrokerInfoData()
    }
}

struct DataBrokerProfileQueryView: View {
    @State private var selectedItem: DataBrokerInfoData?
    @ObservedObject var viewModel: DataBrokerProfileQueryViewModel

    var body: some View {
        NavigationView {
            List(viewModel.dataInfo) { item in
                NavigationLink(destination: DetailView(item: item)) {
                    Text(item.dataBrokerName)
                }
            }
            .frame(minWidth: 200)

            if let selectedItem = selectedItem {
                DetailView(item: selectedItem)
            }
        }
    }
}

struct DetailView: View {
    let item: DataBrokerInfoData

    var body: some View {
        VStack {
            Text("Detail for \(item.dataBrokerName)")
                .font(.title)
                .padding()

            DetailViewSubItem(viewData: ViewData(title: "Scan Operation",
                                                 events: item.scanData.historyEvents,
                                                 preferredRunDate: item.scanData.preferredRunDate))

            List(item.optOutsData) { item in
                DetailViewSubItem(viewData: ViewData(title: "OptOut Operation \(item.extractedProfileName)",
                                                     events: item.historyEvents,
                                                     preferredRunDate: item.preferredRunDate))
            }
            .frame(minWidth: 200)
        }
    }
}

struct DetailViewSubItem: View {
    let viewData: ViewData
    @State private var showModal = false

    var body: some View {
        VStack {
            Button(action: {
                showModal = true
            }) {
                Text(viewData.title)
                    .padding()
                    .cornerRadius(8)
            }
        }
        .padding()
        .sheet(isPresented: $showModal) {
            ModalView(viewData: viewData, showModal: $showModal)
                .frame(width: 600, height: 400)
        }
    }
}

struct ModalView: View {
    let viewData: ViewData
    @Binding var showModal: Bool

    var body: some View {
        VStack {
            Text(viewData.title)
            List(viewData.events) { item in
                HStack {
                    Text("⚠️")
                    Text(formatDate(item.date))
                    Text(labelForEvent(item))
                }
            }
            Text("🗓️ PreferredRunDate \(viewData.formattedRunDate)")
            Button(action: {
                dismissModal()
            }) {
                Text("Close")
                    .padding()
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }

    func dismissModal() {
        showModal = false
    }

    func formatDate(_ date: Date) -> String {
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
        }
    }
}

struct ViewData {
    let title: String
    let events: [HistoryEvent]
    let preferredRunDate: Date?

    var formattedRunDate: String {
        if let date = preferredRunDate {
            return formatDate(date)
        } else {
            return "No date set"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
