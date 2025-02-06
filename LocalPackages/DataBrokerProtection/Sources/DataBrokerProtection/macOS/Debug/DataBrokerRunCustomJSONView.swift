//
//  DataBrokerRunCustomJSONView.swift
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
import BrowserServicesKit

struct DataBrokerRunCustomJSONView: View {
    @ObservedObject var viewModel: DataBrokerRunCustomJSONViewModel

    @State private var jsonText: String = ""

    var body: some View {
        if viewModel.results.isEmpty {
            VStack(alignment: .leading) {
                Text("macOS App version: \(viewModel.appVersion())")

                Divider()

                ForEach(viewModel.names.indices, id: \.self) { index in
                    HStack {
                        TextField("First name", text: $viewModel.names[index].first)
                            .padding()
                        TextField("Middle", text: $viewModel.names[index].middle)
                            .padding()
                        TextField("Last name", text: $viewModel.names[index].last)
                            .padding()
                    }
                }

                Button("Add other name") {
                    viewModel.names.append(.empty())
                }

                Divider()

                ForEach(viewModel.addresses.indices, id: \.self) { index in
                    HStack {
                        TextField("City", text: $viewModel.addresses[index].city)
                            .padding()
                        TextField("State (two characters format)", text: $viewModel.addresses[index].state)
                            .onChange(of: viewModel.addresses[index].state) { newValue in
                                if newValue.count > 2 {
                                    viewModel.addresses[index].state = String(newValue.prefix(2))
                                }
                            }
                            .padding()
                    }
                }

                Button("Add other address") {
                    viewModel.addresses.append(.empty())
                }

                Divider()

                HStack {
                    TextField("Birth year (YYYY)", text: $viewModel.birthYear)
                        .padding()
                }

                Divider()

                List(viewModel.brokers.sorted(by: { $0.name.lowercased() < $1.name.lowercased() }), id: \.name) { broker in
                    Text(broker.name)
                        .onTapGesture {
                            jsonText = broker.toJSONString()
                        }
                }.navigationTitle("Current brokers")

                Divider()

                TextEditor(text: $jsonText)
                    .border(Color.gray, width: 1)
                    .padding()

                Divider()
                Button("Run") {
                    viewModel.runJSON(jsonString: jsonText)
                }

                if viewModel.isRunningOnAllBrokers {
                    ProgressView("Scanning...")
                } else {
                    Button("Run all brokers") {
                        viewModel.runAllBrokers()
                    }
                }
            }
            .padding()
            .frame(minWidth: 600, minHeight: 800)
            .alert(isPresented: $viewModel.showAlert) {
                            Alert(title: Text(viewModel.alert?.title ?? "-"),
                                  message: Text(viewModel.alert?.description ?? "-"),
                                  dismissButton: .default(Text("OK"), action: { viewModel.showAlert = false })
                            )
                        }
        } else {
            VStack {
                VStack {
                    List(viewModel.results, id: \.id) { scanResult in
                        HStack {
                            Text(scanResult.extractedProfile.name ?? "No name")
                                .padding(.horizontal, 10)
                            Divider()
                            Text(scanResult.extractedProfile.addresses?.map { $0.fullAddress }.joined(separator: ", ") ?? "No address")
                                .padding(.horizontal, 10)
                            Divider()
                            Text(scanResult.extractedProfile.relatives?.joined(separator: ",") ?? "No relatives")
                                .padding(.horizontal, 10)
                            Divider()
                            Button("Opt-out") {
                                viewModel.runOptOut(scanResult: scanResult)
                            }
                        }
                    }.navigationTitle("Results")
                }.frame(minWidth: 600, minHeight: 800)

                Divider()

                Button("Clear and go back") {
                    viewModel.results.removeAll()
                }.padding()
            }.alert(isPresented: $viewModel.showAlert) {
                Alert(title: Text(viewModel.alert?.title ?? "-"),
                      message: Text(viewModel.alert?.description ?? "-"),
                      dismissButton: .default(Text("OK"), action: { viewModel.showAlert = false })
                )
            }
        }
    }
}
