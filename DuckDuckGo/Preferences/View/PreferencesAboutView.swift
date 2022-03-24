//
//  PreferencesAboutView.swift
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

struct TextButton: View {
    
    let title: String
    let action: () -> Void
    
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundColor(Color("LinkBlueColor"))
        }
        .buttonStyle(.plain)
    }
}

extension Preferences {
    
    struct AboutView: View {
        @ObservedObject var model: AboutModel
        
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("About DuckDuckGo")
                    .font(Const.Fonts.preferencePaneTitle)
                
                HStack {
                    Image("AboutPageLogo")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DuckDuckGo").font(.companyName)
                        Text("Privacy, simplified").font(.privacySimplified)
                        Text(UserText.versionLabel(version: model.appVersion.versionNumber, build: model.appVersion.buildNumber))
                    }
                }

                HStack {
                    TextButton("More at duckduckgo.com/about") {
                        model.openURL(.aboutDuckDuckGo)
                    }
#if FEEDBACK
                    Spacer()
                    Button("Send Feedback") {
                        model.openFeedbackForm()
                    }
                    Spacer()
#endif
                }
                
                TextButton("Privacy Policy") {
                    model.openURL(.privacyPolicy)
                }
            }
        }
    }
    
}

fileprivate extension Font {
    static let companyName: Font = .title
    static let privacySimplified: Font = {
        if #available(macOS 11.0, *) {
            return .title3.weight(.semibold)
        } else {
            return .system(size: 15, weight: .semibold)
        }
    }()
}

struct PreferencesAboutView_Previews: PreviewProvider {
    static var previews: some View {
        Preferences.AboutView(model: .init())
    }
}
