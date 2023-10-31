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

struct DataBrokerProtectionContainerView: View {
    @ObservedObject var containerViewModel: ContainerViewModel
    @ObservedObject var navigationViewModel: ContainerNavigationViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @ObservedObject var resultsViewModel: ResultsViewModel
    @State var shouldShowDebugUI = false

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
                                containerViewModel.scanAfterProfileCreation { scanResult in
                                    updateUIWithScanResult(scanResult: scanResult)

                                    if scanResult == .results && !DataBrokerDebugFlagBlockScheduler().isFlagOn() {
                                        containerViewModel.runQueuedOperationsAndStartScheduler()
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

                if shouldShowDebugUI {
                    VStack {
                        HStack {
                            debugUI()
                                .padding()
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }.background(
            backgroundView()
        )
    }

    private func updateUIWithScanResult(scanResult: ContainerViewModel.ScanResult) {
        if navigationViewModel.bodyViewType != .scanStarted {
            return
        }
        switch scanResult {
        case .noResults:
            navigationViewModel.updateNavigation(.noResults)
        case .results:
            resultsViewModel.reloadData()
            navigationViewModel.updateNavigation(.results)
        }
    }

    @ViewBuilder
    private func debugUI() -> some View {
        VStack(alignment: .leading) {
            Toggle("Use Fake Broker", isOn: $containerViewModel.useFakeBroker)

            Toggle("Display WebViews", isOn: $containerViewModel.showWebView)

            Toggle("Block Scheduler", isOn: $containerViewModel.preventSchedulerStart)

            Button {
                containerViewModel.forceSchedulerRun()
            } label: {
                Text("Force operations run")
            }

            Button {
                containerViewModel.forceRunScans { result in
                    updateUIWithScanResult(scanResult: result)
                }
            } label: {
                Text("Run Scans")
            }

            Button {
                containerViewModel.forceRunOptOuts()
            } label: {
                Text("Run Opt-Outs")
            }

            Button {
                containerViewModel.cleanData()
            } label: {
                Text("Clean Data & Close")
            }

            HStack {
                Picker(selection: $navigationViewModel.bodyViewType,
                       label: Text("Body View Type")) {
                    ForEach(ContainerNavigationViewModel.BodyViewType.allCases, id: \.self) { viewType in
                        Text(viewType.description).tag(viewType)
                    }
                }
                       .pickerStyle(MenuPickerStyle())
                       .frame(width: 300)
            }
        }
        .padding()
        .blurredBackground()
    }

    @ViewBuilder
    private func headerView() -> some View {
        if navigationViewModel.bodyViewType != .createProfile {
            VStack {

                DashboardHeaderView(resultsViewModel: resultsViewModel,
                                    displayProfileButton: navigationViewModel.bodyViewType != .gettingStarted,
                                    faqButtonClicked: {
                    shouldShowDebugUI.toggle()
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
        if  navigationViewModel.bodyViewType != .createProfile {
            Color("background-color", bundle: .module)
        } else {
            Image("background-pattern", bundle: .module)
                .resizable()
        }
    }
}

struct DataBrokerProtectionContainerView_Previews: PreviewProvider {
    static var previews: some View {
        let dataManager = PreviewDataManager()
        let navigationViewModel = ContainerNavigationViewModel(dataManager: dataManager)
        let profileViewModel = ProfileViewModel(dataManager: dataManager)
        let resultsViewModel = ResultsViewModel(dataManager: dataManager)
        let containerViewModel = ContainerViewModel(scheduler: DataBrokerProtectionNoOpScheduler(), dataManager: dataManager)

        DataBrokerProtectionContainerView(containerViewModel: containerViewModel,
                                          navigationViewModel: navigationViewModel,
                                          profileViewModel: profileViewModel,
                                          resultsViewModel: resultsViewModel)
        .frame(width: 1024, height: 768)
    }
}

extension View {
    @ViewBuilder
    func blurredBackground() -> some View {
        if #available(macOS 12.0, *) {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        } else {
            self
        }
    }
}
