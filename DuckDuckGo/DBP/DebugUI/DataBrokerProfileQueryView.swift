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
        print("AAAAAA")
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

            DetailViewSubItem(historyItems: item.scanData.historyEvents, title: "Scan Operation")

            List(item.optOutsData) { item in
                DetailViewSubItem(historyItems: item.historyEvents, title: "OptOut \(item.extractedProfileName)")

            }
            .frame(minWidth: 200)
        }
    }
}

struct DetailViewSubItem: View {
    let historyItems: [HistoryEvent]
    let title: String
    @State private var showModal = false

    var body: some View {
        VStack {
            Button(action: {
                showModal = true
            }) {
                Text(title)
                    .padding()
                    .cornerRadius(8)
            }
        }
        .padding()
        .sheet(isPresented: $showModal) {
            ModalView(title: title, historyItems: historyItems, showModal: $showModal)
                .frame(width: 600, height: 400)
        }
    }
}

struct ModalView: View {
    let title: String
    let historyItems: [HistoryEvent]
    @Binding var showModal: Bool

    var body: some View {
        VStack {
            Text(title)
            List(historyItems) { item in
                HStack {
                    Text("⚠️")
                    Text(formatDate(item.date))
                    Text(labelForEvent(item))
                }
            }
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
        case .matchFound(extractedProfileID: let extractedProfileID):
            return "Match found \(extractedProfileID)"
        case .error:
            return "Error"
        case .optOutStarted(extractedProfileID: let extractedProfileID):
            return "Opt-out started \(extractedProfileID)"
        case .optOutRequested(extractedProfileID: let extractedProfileID):
            return "Opt-out requested \(extractedProfileID)"
        case .optOutConfirmed(extractedProfileID: let extractedProfileID):
            return "Opt-out confirmed \(extractedProfileID)"
        case .scanStarted:
            return "Scan Started"
        }
    }
}
