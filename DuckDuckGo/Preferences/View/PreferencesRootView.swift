//
//  PreferencesRootView.swift
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

extension Preferences {
    
    struct RootView: View {
        
        @ObservedObject var model: PreferencesModel
        
        var body: some View {
            HStack(spacing: 0) {
                Preferences.Sidebar().environmentObject(model).frame(width: 252)
                Color(NSColor.separatorColor).frame(width: 1)
                
                ScrollView(.vertical) {
                    HStack(alignment: .top) {
                        Spacer()

                        VStack(alignment: .leading) {
                            
                            switch model.selectedPane {
                            case .defaultBrowser:
                                DefaultBrowserView(model: DefaultBrowserPreferencesModel())
                            case .appearance:
                                AppearanceView(model: .shared)
                            case .privacy:
                                PrivacyView(model: PrivacyPreferencesModel())
                            case .loginsPlus:
                                LoginsView(model: LoginsPreferencesModel())
                            case .downloads:
                                DownloadsView(model: DownloadsPreferencesModel())
                            case .about:
                                AboutView(model: .init())
                            }
                        }
                        .frame(maxWidth: 512, maxHeight: .infinity, alignment: .topLeading)
                        .padding(40)

                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("InterfaceBackgroundColor"))
        }
    }

}

struct PreferencesRootView_Previews: PreviewProvider {
    static var previews: some View {
        Preferences.RootView(model: .init())
    }
}
