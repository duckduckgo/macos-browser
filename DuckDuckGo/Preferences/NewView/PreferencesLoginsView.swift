//
//  PreferencesLoginsView.swift
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
    
    struct LoginsView: View {
        @ObservedObject var model: LoginsPreferencesModel

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(UserText.loginsPlus)
                    .font(Const.Fonts.preferencePaneTitle)
                    .padding(.bottom, 24)
                
                Text(UserText.loginsPlusAskToSave)
                    .font(Const.Fonts.preferencePaneSectionHeader)
                    .padding(.bottom, 6)
                
                Text(UserText.loginsPlusAskToSaveExplanation)
                    .font(Const.Fonts.preferencePaneCaption)
                    .foregroundColor(Color("GreyTextColor"))
                    .fixMultilineScrollableText()
                    .padding(.bottom, 12)
                
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(UserText.loginsPlusUsernamesAndPasswords, isOn: .constant(true))
                        .fixMultilineScrollableText()
                    Toggle(UserText.loginsPlusAddresses, isOn: .constant(true))
                        .fixMultilineScrollableText()
                    Toggle(UserText.loginsPlusPaymentMethods, isOn: .constant(true))
                        .fixMultilineScrollableText()
                }
                .padding(.bottom, 42)

                Text(UserText.loginsPlusAutoLock)
                    .font(Const.Fonts.preferencePaneSectionHeader)
                    .padding(.bottom, 12)
                
                Picker(selection: $model.shouldAutoLockLogins, content: {
                    HStack {
                        Text(UserText.loginsPlusLockWhenIdle)
                        NSPopUpButtonView(selection: $model.autoLockThreshold) {
                            let button = NSPopUpButton()
                            button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
                            
                            for threshold in LoginsPreferencesModel.AutoLockThreshold.allCases {
                                let item = button.menu?.addItem(withTitle: threshold.title, action: nil, keyEquivalent: "")
                                item?.representedObject = threshold
                            }
                            return button
                        }
                        .disabled(!model.shouldAutoLockLogins)
                    }.tag(true)
                    Text(UserText.loginsPlusNeverLock).tag(false)
                }, label: {})
                    .pickerStyle(.radioGroup)
                    .offset(x: autoLockPickerHorizontalOffset)
                    .padding(.bottom, 6)

                Text(UserText.loginsPlusNeverLockWarning)
                    .font(Const.Fonts.preferencePaneCaption)
                    .foregroundColor(Color("GreyTextColor"))
                    .fixMultilineScrollableText()
                    .offset(x: 18)
            }
        }
        
        var autoLockPickerHorizontalOffset: CGFloat {
            if #available(macOS 12.0, *) {
                return -8
            } else {
                return 0
            }
        }
    }

}

struct PreferencesLoginsView_Previews: PreviewProvider {
    static var previews: some View {
        Preferences.LoginsView(model: .init())
    }
}
