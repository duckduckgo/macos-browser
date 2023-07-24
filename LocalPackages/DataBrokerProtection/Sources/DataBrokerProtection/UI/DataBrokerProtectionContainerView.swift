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

private enum BodyViewType {
    case gettingStarted
    case noResults
}

@available(macOS 11.0, *)
public struct DataBrokerProtectionContainerView: View {
    @State private var bodyViewType = BodyViewType.noResults

    public init() { }

    public var body: some View {
        ScrollView {
            ZStack {
                VStack {
                    DashboardHeaderView(viewModel: DashboardHeaderViewModel(statusText: "Scanning...",
                                                                            faqButtonClicked: {},
                                                                            editProfileClicked: {}))
                    .frame(height: 300)
                    Spacer()
                }
                VStack {
                    switch bodyViewType {
                    case .gettingStarted:
                        GettingStartedView()
                            .padding(.top, 200)
                    case .noResults:
                        NoResultsFoundView()
                            .padding(.top, 330)
                    }

                    Spacer()
                }
            }
        }.background(Color("background-color", bundle: .module))
    }
}

@available(macOS 11.0, *)
struct DataBrokerProtectionContainerView_Previews: PreviewProvider {
    static var previews: some View {
        DataBrokerProtectionContainerView()
            .frame(width: 1024, height: 768)
    }
}
