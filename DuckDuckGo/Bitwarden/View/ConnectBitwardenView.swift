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

private enum ConnectBitwardenStatus {
    case disclaimer
}

struct ConnectBitwardenView: View {
    
    var body: some View {
        Group {
            VStack {
                BitwardenTitleView()
                
                ConnectToBitwardenDisclaimerView()
            }
        }
        .padding(20)
        
        Spacer()
        Divider()
        
        HStack {
            Spacer()
            
            Button("Cancel") {
                print("Cancel")
            }
            .buttonStyle(BorderedButtonStyle())
            
            Button("Next") {
                print("Next")
            }
        }
        .padding([.trailing, .bottom], 16)
        .padding([.top], 10)
    }
    
}

struct BitwardenTitleView: View {
    
    var body: some View {
        
        HStack(spacing: 10) {
            Image("BitwardenLogo")
                .resizable()
                .frame(width: 32, height: 32)
            
            Text("Connect to Bitwarden")
                .font(.title)
            
            Spacer()
        }

    }
    
}

struct ConnectToBitwardenDisclaimerView: View {
    
    var body: some View {
        VStack {
            Text("We’ll walk you through connecting to Bitwarden, so you can use it in DuckDuckGo.")
            
            Text("Privacy")
                .font(.title)
        }
    }
    
}

// Commented out because it's too hard for Xcode to display a SwiftUI preview
//
//struct ConnectBitwardenView_Previews: PreviewProvider {
//    static var previews: some View {
//        ConnectBitwardenView()
//    }
//}
