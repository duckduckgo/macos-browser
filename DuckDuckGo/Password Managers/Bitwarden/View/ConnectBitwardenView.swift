//
//  ConnectBitwardenView.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import Foundation
import SwiftUI

struct ConnectBitwardenView: View {
    
    private enum Constants {
        static let headerPadding = 20.0
        static let bodyPadding = 20.0
    }

    struct ViewSize {
        fileprivate(set) var headerHeight: Double = 0.0
        fileprivate(set) var viewHeight: Double = 0.0
        fileprivate(set) var buttonsHeight: Double = 0.0
        
        var totalHeight: Double {
            headerHeight + Constants.headerPadding + viewHeight + Constants.bodyPadding + buttonsHeight
        }
    }
    
    @EnvironmentObject var viewModel: ConnectBitwardenViewModel
    
    let sizeChanged: (CGFloat) -> Void
    
    @State var viewSize: ViewSize = .init() {
        didSet {
            sizeChanged(viewSize.totalHeight)
        }
    }
    
    var body: some View {
        VStack {
            VStack(spacing: Constants.bodyPadding) {
                BitwardenTitleView()
                    .background(
                        GeometryReader { proxy in
                            Color.clear.onAppear {
                                viewSize.headerHeight = proxy.size.height
                            }
                        }
                    )
                
                bodyView(for: viewModel.viewState)
                    .frame(maxWidth: .infinity)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.onAppear {
                                viewSize.viewHeight = proxy.size.height
                            }
                        }
                    )
            }
            .padding(20)
            
            Spacer()
            
            ButtonsView()
                .background(
                    GeometryReader { proxy in
                        Color.clear.onAppear {
                            viewSize.buttonsHeight = proxy.size.height
                        }
                    }
                )
        }
    }
    
    @ViewBuilder private func bodyView(for state: ConnectBitwardenViewModel.ViewState) -> some View {
        switch viewModel.viewState {
        case .disclaimer: ConnectToBitwardenDisclaimerView()
        case .lookingForBitwarden: BitwardenInstallationDetectionView(bitwardenDetected: false)
        case .bitwardenFound: BitwardenInstallationDetectionView(bitwardenDetected: true)
        case .waitingForConnectionPermission: ConnectToBitwardenView(canConnect: false)
        case .connectToBitwarden: ConnectToBitwardenView(canConnect: true)
        case .connectedToBitwarden: ConnectedToBitwardenView()
        }
    }
    
}

struct BitwardenTitleView: View {
    
    var body: some View {
        
        HStack(spacing: 10) {
            Image("BitwardenLogo")
                .resizable()
                .frame(width: 32, height: 32)
            
            Text(UserText.connectToBitwarden)
                .font(.system(size: 18, weight: .semibold))
            
            Spacer()
        }

    }
    
}

private struct ConnectToBitwardenDisclaimerView: View {
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(UserText.connectToBitwardenDescription)
            
            Text(UserText.connectToBitwardenPrivacy)
                .font(.system(size: 13, weight: .bold))
                .padding(.top, 10)
            
            HStack {
                Image("BitwardenLock")
                Text(UserText.bitwardenCommunicationInfo)
            }
            
            HStack {
                Image("BitwardenClock")
                Text(UserText.bitwardenHistoryInfo)
            }
        }
    }
    
}

private struct BitwardenInstallationDetectionView: View {
    
    @EnvironmentObject var viewModel: ConnectBitwardenViewModel
    
    let bitwardenDetected: Bool
    
    var body: some View {

        VStack(alignment: .leading, spacing: 10) {
            Text(UserText.installBitwarden)
                .font(.system(size: 13, weight: .bold))
            
            HStack {
                NumberedBadge(value: 1)

                Text(UserText.installBitwardenInfo)
                
                Spacer()
            }
            
            HStack {
                NumberedBadge(value: 2)
                
                Text(UserText.afterBitwardenInstallationInfo)
                
                Spacer()
            }
            
            Button(action: {
                viewModel.process(action: .openBitwardenProductPage)
            }, label: {
                Image("MacAppStoreButton")
            })
            .buttonStyle(PlainButtonStyle())
            .frame(width: 156, height: 40)

            Spacer().frame(height: 170)

            if bitwardenDetected {
                HStack {
                    Image("SuccessCheckmark")
                    Text(UserText.bitwardenAppFound)
                }
            } else {
                HStack {
                    ActivityIndicator(isAnimating: .constant(true), style: .spinning)
                    
                    Text(UserText.lookingForBitwaden)
                }
            }
        }
        .frame(maxWidth: .infinity)

    }
    
}

private struct ConnectToBitwardenView: View {
    
    @EnvironmentObject var viewModel: ConnectBitwardenViewModel
    
    let canConnect: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(UserText.allowIntegration)
                .font(.system(size: 13, weight: .bold))
            
            HStack {
                NumberedBadge(value: 1)
                Text(UserText.openBitwadenAndLogInOrUnlock)
                Spacer()
            }
            
            HStack {
                NumberedBadge(value: 2)
                Text(UserText.selectBitwadenPreferences)
                Spacer()
            }
            
            HStack {
                NumberedBadge(value: 3)
                Text(UserText.scrollToFindAppSettings)
                Spacer()
            }
            
            HStack {
                NumberedBadge(value: 4)
                Text(UserText.checkAllowIntegration)
                Spacer()
            }
            
            Image("BitwardenSettingsIllustration")
            
            Button(UserText.openBitwaden) {
                viewModel.process(action: .openBitwarden)
            }
            
            if canConnect {
                HStack {
                    Image("SuccessCheckmark")
                    
                    Text(UserText.bitwardenIsReadyToConnect)
                    
                    Spacer()
                }
            } else {
                
                HStack {
                    ActivityIndicator(isAnimating: .constant(true), style: .spinning)
                        .frame(maxWidth: 8, maxHeight: 8)

                    Text(UserText.bitwardenWaitingForPermissions)
                }
            }
        }
    }
    
}

private struct ConnectedToBitwardenView: View {

    var body: some View {
        VStack(alignment: .leading) {
            
            Text(UserText.bitwardenIntegrationComplete)
                .font(.system(size: 13, weight: .bold))
            
            HStack {
                Image("SuccessCheckmark")

                Text(UserText.bitwardenIntegrationCompleteInfo)
                
                Spacer()
            }

        }
        .frame(maxWidth: .infinity)
    }
    
}

// MARK: - Reusable Views

private struct NumberedBadge: View {
    
    let value: Int

    var body: some View {
        ZStack {
            Circle().fill(.blue) // Color(hex: "3969EF").opacity(0.12)

            Text("\(value)")
                .foregroundColor(.white) // Color(hex: "2B55CA")
        }
        .frame(width: 20, height: 20)
    }
    
}

private struct ButtonsView: View {
    
    @EnvironmentObject var viewModel: ConnectBitwardenViewModel
    
    var body: some View {
        
        Divider()
        
        HStack {
            Spacer()
            
            if viewModel.viewState.cancelButtonVisible {
                Button(UserText.cancel) {
                    viewModel.process(action: .cancel)
                }
            }
            
            if #available(macOS 11.0, *) {
                Button(viewModel.viewState.confirmButtonTitle) {
                    viewModel.process(action: .confirm)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.viewState.canContinue)
            } else {
                Button(viewModel.viewState.confirmButtonTitle) {
                    viewModel.process(action: .confirm)
                }
                .disabled(!viewModel.viewState.canContinue)
            }
        }
        .padding([.trailing, .bottom], 16)
        .padding(.top, 10)
        
    }
    
}

struct ActivityIndicator: NSViewRepresentable {
    
    @Binding var isAnimating: Bool

    let style: NSProgressIndicator.Style

    func makeNSView(context: NSViewRepresentableContext<ActivityIndicator>) -> NSProgressIndicator {
        let progressIndicator = NSProgressIndicator()
        progressIndicator.style = self.style
        progressIndicator.controlSize = .small
        return progressIndicator
    }

    func updateNSView(_ nsView: NSProgressIndicator, context: NSViewRepresentableContext<ActivityIndicator>) {
        isAnimating ? nsView.startAnimation(nil) : nsView.stopAnimation(nil)
    }
    
}
