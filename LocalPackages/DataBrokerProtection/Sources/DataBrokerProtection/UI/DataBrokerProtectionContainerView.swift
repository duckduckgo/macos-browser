//
//  DataBrokerProtectionContainerView.swift
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

private enum BodyViewType: CaseIterable {
    case gettingStarted
    case noResults
    case scanStarted
    case results
    case createProfile

    var description: String {
        switch self {
        case .gettingStarted:
            return "Getting Started"
        case .noResults:
            return "No Results Found"
        case .scanStarted:
            return "Scan Started"
        case .results:
            return "Results"
        case .createProfile:
            return "Create Profile"
        }
    }
}

@available(macOS 11.0, *)
public struct DataBrokerProtectionContainerView: View {
    @State private var bodyViewType = BodyViewType.createProfile

    private var shouldShowHeader: Bool {
        bodyViewType != .createProfile
    }

    public init() { }

    public var body: some View {
        ScrollView {
            ZStack {
                headerView()

                VStack {
                    switch bodyViewType {
                    case .gettingStarted:
                        GettingStartedView()
                            .padding(.top, 200)
                    case .noResults:
                        NoResultsFoundView()
                            .padding(.top, 330)
                    case .scanStarted:
                        ScanStartedView()
                            .padding(.top, 330)
                    case .results:
                        ResultsView(viewModel: ResultsViewModel())
                            .frame(width: 800)
                            .padding(.top, 330)
                            .padding(.bottom, 100)
                    case .createProfile:
                        CreateProfileView()
                            .frame(width: 670)
                            .padding(.top, 73)
                    }
                    Spacer()
                }

                // TODO: Remove, just for testing
                VStack(alignment: .leading) {
                    HStack {
                        Picker(selection: $bodyViewType, label: Text("Body View Type")) {
                            ForEach(BodyViewType.allCases, id: \.self) { viewType in
                                Text(viewType.description).tag(viewType)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 300)

                        Spacer()
                    }
                    Spacer()
                }.padding()
            }
        }.background(
           backgroundView()
        )
    }

    @ViewBuilder
    func headerView() -> some View {
        if shouldShowHeader {
            VStack {
                DashboardHeaderView(viewModel: DashboardHeaderViewModel(statusText: "Scanning...",
                                                                        faqButtonClicked: {},
                                                                        editProfileClicked: {}))
                .frame(height: 300)
                Spacer()
            }
        }
    }

    @ViewBuilder
    func backgroundView() -> some View {
        if shouldShowHeader {
            Color("background-color", bundle: .module)
        } else {
            Image("background-pattern", bundle: .module)
                .resizable()
        }
    }
}

@available(macOS 11.0, *)
struct DataBrokerProtectionContainerView_Previews: PreviewProvider {
    static var previews: some View {
        DataBrokerProtectionContainerView()
            .frame(width: 1024, height: 768)
    }
}
