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
    
    @EnvironmentObject var viewModel: ConnectBitwardenViewModel
    
    var body: some View {
        VStack {
            BitwardenTitleView()
                .padding(.bottom, 10)
            
            switch viewModel.viewState {
            case .disclaimer:
                ConnectToBitwardenDisclaimerView()
            case .lookingForBitwarden:
                BitwardenInstallationDetectionView(bitwardenDetected: false)
            case .bitwardenFound:
                BitwardenInstallationDetectionView(bitwardenDetected: true)
            default:
                Text("\(viewModel.viewState.hashValue)")
            }
        }
        .padding(20)
        
        Spacer()
        
        ButtonsView()
    }
    
}

struct BitwardenTitleView: View {
    
    var body: some View {
        
        HStack(spacing: 10) {
            Image("BitwardenLogo")
                .resizable()
                .frame(width: 32, height: 32)
            
            Text("Connect to Bitwarden")
                .font(.system(size: 18, weight: .semibold))
            
            Spacer()
        }

    }
    
}

private struct ConnectToBitwardenDisclaimerView: View {
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("We’ll walk you through connecting to Bitwarden, so you can use it in DuckDuckGo.")
            
            Text("Privacy")
                .font(.system(size: 13, weight: .bold))
                .padding(.top, 10)
            
            HStack {
                Image("BitwardenLock")
                Text("All communication between Bitwarden and DuckDuckGo is encrypted and the data never leaves your device.")
            }
            
            HStack {
                Image("BitwardenClock")
                Text("Bitwarden will have access to your browsing history.")
            }
        }
    }
    
}

private struct BitwardenInstallationDetectionView: View {
    
    let bitwardenDetected: Bool
    
    var body: some View {

        VStack(alignment: .leading) {
            Text("Install Bitwarden")
                .font(.system(size: 13, weight: .bold))
                .padding(.top, 10)
            
            Button(action: {
                print("Opening Mac App Store")
            }, label: {
                Image("MacAppStoreButton")
            })
            .buttonStyle(PlainButtonStyle())
            .frame(width: 156, height: 40)
            
            if bitwardenDetected {
                Text("Bitwarden found!")
            } else {
                HStack {
                    ActivityIndicator(isAnimating: .constant(true), style: .spinning)
                    
                    Text("Looking for Bitwarden app...")
                }
            }
        }

    }
    
}

private struct ButtonsView: View {
    
    @EnvironmentObject var viewModel: ConnectBitwardenViewModel
    
    var body: some View {
        
        Divider()
        
        HStack {
            Spacer()
            
            Button("Cancel") {
                viewModel.process(action: .cancel)
            }
            
            if #available(macOS 11.0, *) {
                Button("Next") {
                    viewModel.process(action: .confirm)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.viewState.canContinue)
            } else {
                Button("Next") {
                    viewModel.process(action: .confirm)
                }
                .disabled(!viewModel.viewState.canContinue)
            }
        }
        .padding([.trailing, .bottom], 16)
        .padding([.top], 10)
        
    }
    
}

struct ActivityIndicator: NSViewRepresentable {
    
    @Binding var isAnimating: Bool

    let style: NSProgressIndicator.Style

    func makeNSView(context: NSViewRepresentableContext<ActivityIndicator>) -> NSProgressIndicator {
        let progressIndicator = NSProgressIndicator()
        progressIndicator.style = self.style
        return progressIndicator
    }

    func updateNSView(_ nsView: NSProgressIndicator, context: NSViewRepresentableContext<ActivityIndicator>) {
        isAnimating ? nsView.startAnimation(nil) : nsView.stopAnimation(nil)
    }
    
}
