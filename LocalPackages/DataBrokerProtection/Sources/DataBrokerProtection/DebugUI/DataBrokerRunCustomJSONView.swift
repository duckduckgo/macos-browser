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
                Text("C-S-S version: \(viewModel.contentScopeScriptsVersion())")

                Divider()

                HStack {
                    TextField("First name", text: $viewModel.firstName)
                        .padding()
                    TextField("Last name", text: $viewModel.lastName)
                        .padding()
                    TextField("Middle", text: $viewModel.middle)
                        .padding()
                }

                Divider()

                HStack {
                    TextField("City", text: $viewModel.city)
                        .padding()
                    TextField("State", text: $viewModel.state)
                        .padding()
                }

                Divider()

                HStack {
                    TextField("Birth year (YYYY)", text: $viewModel.birthYear)
                        .padding()
                }

                Divider()

                List(viewModel.brokers, id: \.name) { broker in
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
                    List(viewModel.results, id: \.name) { extractedProfile in
                        HStack {
                            Text(extractedProfile.name ?? "No name")
                                .padding(.horizontal, 10)
                            Divider()
                            Text(extractedProfile.addresses?.first?.fullAddress ?? "No address")
                                .padding(.horizontal, 10)
                            Divider()
                            Text(extractedProfile.relatives?.joined(separator: ",") ?? "No relatives")
                                .padding(.horizontal, 10)
                            Divider()
                            Button("Opt-out") {
                                viewModel.runOptOut(extractedProfile: extractedProfile)
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
