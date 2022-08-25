//
//  PrivateYoutubeDiscoveryView.swift
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

import SwiftUI

struct PrivateYoutubeDiscoveryView: View {
    var body: some View {
        HStack(spacing: 30) {
            Image("Private-youtube-player-image")
                .resizable()
                .frame(width: 100, height: 64)
            
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                Text("Watch this video privately")
                    .font(.title3)
                Text("DuckDuckGo YouTube Player removes cookies and trackers from YouTube videos so you can watch them without personalized ads and without influencing your YouTube recommendations.")
                }
                
                HStack {
                    Button {
                        
                    } label: {
                        Text("No Thanks")
                            .frame(maxWidth: .infinity)
                    }
                    
                    Button {
                        
                    } label: {
                        Text("Try it Now")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding()
        .frame(width: 440, height: 170)
    }
}

struct PrivateYoutubeDiscoveryView_Previews: PreviewProvider {
    static var previews: some View {
        PrivateYoutubeDiscoveryView()
    }
}
