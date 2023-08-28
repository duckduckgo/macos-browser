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

final class ContainerViewModel: ObservableObject {
    enum ScanResult {
        case noResults
        case results
    }

    let scheduler: DataBrokerProtectionScheduler
    let dataManager: DataBrokerProtectionDataManaging

    internal init(scheduler: DataBrokerProtectionScheduler,
                  dataManager: DataBrokerProtectionDataManaging) {
        self.scheduler = scheduler
        self.dataManager = dataManager
    }

    func scan(completion: @escaping (ScanResult) -> Void) {
        scheduler.scanAllBrokers { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                let brokerProfileData = self.dataManager.fetchBrokerProfileQueryData()
                let data = brokerProfileData.filter { !$0.optOutOperationsData.isEmpty }
                if data.isEmpty {
                    completion(.noResults)
                } else {
                    completion(.results)
                }
            }
        }
    }
}

@available(macOS 11.0, *)
struct DataBrokerProtectionContainerView: View {
    @ObservedObject var containerViewModel: ContainerViewModel
    @ObservedObject var navigationViewModel: ContainerNavigationViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @ObservedObject var resultsViewModel: ResultsViewModel

    var body: some View {
        ScrollView {
            ZStack {
                headerView()

                VStack {
                    switch navigationViewModel.bodyViewType {
                    case .gettingStarted:
                        GettingStartedView(buttonClicked: {
                            navigationViewModel.updateNavigation(.createProfile)
                        })
                        .padding(.top, 200)
                    case .noResults:
                        NoResultsFoundView(buttonClicked: {
                            navigationViewModel.updateNavigation(.createProfile)
                        })
                        .padding(.top, 330)
                    case .scanStarted:
                        ScanStartedView()
                            .padding(.top, 330)
                    case .results:
                        ResultsView(viewModel: resultsViewModel)
                            .frame(width: 800)
                            .padding(.top, 330)
                            .padding(.bottom, 100)
                    case .createProfile:
                        CreateProfileView(
                            viewModel: profileViewModel,
                            scanButtonClicked: {
                                navigationViewModel.updateNavigation(.scanStarted)
                                containerViewModel.scan { scanResult in
                                    switch scanResult {
                                    case .noResults:
                                        navigationViewModel.updateNavigation(.noResults)
                                    case .results:
                                        resultsViewModel.reloadData()
                                        navigationViewModel.updateNavigation(.results)
                                    }
                                }
                            }, backToDashboardClicked: {
                                navigationViewModel.updateNavigation(.results)
                            })
                        .frame(width: 670)
                        .padding(.top, 73)
                    }
                    Spacer()
                }

               // just for testing
               VStack(alignment: .leading) {
                   HStack {
                       Picker(selection: $navigationViewModel.bodyViewType, label: Text("Body View Type")) {
                           ForEach(ContainerNavigationViewModel.BodyViewType.allCases, id: \.self) { viewType in
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
        if navigationViewModel.shouldShowHeader {
            VStack {

                DashboardHeaderView(statusText: "",
                                    displayProfileButton: navigationViewModel.bodyViewType != .gettingStarted,
                                    faqButtonClicked: {
                    print("FAQ")
                },
                                    editProfileClicked: {
                    navigationViewModel.updateNavigation(.createProfile)
                })
                .frame(height: 300)
                Spacer()
            }
        }
    }

    @ViewBuilder
    func backgroundView() -> some View {
        if navigationViewModel.shouldShowHeader {
            Color("background-color", bundle: .module)
        } else {
            Image("background-pattern", bundle: .module)
                .resizable()
        }
    }
}

//TODO create scheduler protocol
//@available(macOS 11.0, *)
//struct DataBrokerProtectionContainerView_Previews: PreviewProvider {
//    static var previews: some View {
//        let dataManager = DataBrokerProtectionDataManager()
//        let navigationViewModel = ContainerNavigationViewModel(dataManager: dataManager)
//        let profileViewModel = ProfileViewModel(dataManager: dataManager)
//        let resultsViewModel = ResultsViewModel(dataManager: dataManager)
//        DataBrokerProtectionContainerView(navigationViewModel: navigationViewModel,
//                                          profileViewModel: profileViewModel,
//                                          resultsViewModel: resultsViewModel)
//            .frame(width: 1024, height: 768)
//    }
//}
