//
//  CookieConsentUserPermissionView.swift
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

struct CookieConsentUserPermissionView: View {
    var body: some View {
        
        Group {
            VStack(spacing: 32) {
                HStack(alignment: .top) {
                    daxStackView
                    
                    contentView
                        .frame(width: 406)
                }
                .frame(height: 176)
                
                buttonStack
            }
            .frame(width: 490)
        }
        .padding()
        .background(Color("CookieConsentPanelBackground"))
    }
    
    private var daxStackView: some View {
        VStack {
            HStack {
                Image("OnboardingDax")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 3)
                
                Spacer()
            }
        }
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Looks like this site has a cookie consent pop-up 👇")
                .font(.system(size: 15))
                .fontWeight(.light)
 
            HStack {
                Spacer()
                Image("CookieConsentSketch")
                Spacer()
            }            

            Text("Want me to handle these for you? I can try to minimize cookies, maximize privacy, and hide pop-ups like these.")
                .fontWeight(.light)
                .font(.system(size: 15))
            
        }.frame(maxHeight: .infinity)
    }
    private var buttonStack: some View {
        HStack {
            Button {
                print("Don't")
            } label: {
                Text("No Thanks")
            }
            .buttonStyle(SecondaryCTAStyle())
            
            Button {
                print("Manage")
            } label: {
                Text("Manage Cookie Pop-ups")
            }
            .buttonStyle(PrimaryCTAStyle())
        }

    }
}

struct CookieConsentUserPermissionView_Previews: PreviewProvider {
    static var previews: some View {
        if #available(macOS 11.0, *) {
            CookieConsentUserPermissionView().preferredColorScheme(.dark)
            CookieConsentUserPermissionView().preferredColorScheme(.light)
        } else {
            CookieConsentUserPermissionView()
        }
    }
}

private struct PrimaryCTAStyle: ButtonStyle {
    
    func makeBody(configuration: Self.Configuration) -> some View {

        let color = configuration.isPressed ? Color("OnboardingActionButtonPressedColor") : Color("CookieConsentPrimaryButton")

        configuration.label
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .truncationMode(.tail)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color))
            .foregroundColor(.white)
            .font(.system(size: 13, weight: .light, design: .default))

    }
}

private struct SecondaryCTAStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Self.Configuration) -> some View {
        
        let color = configuration.isPressed ? Color("OnboardingActionButtonPressedColor") : Color("CookieConsentSecondaryButton")
        
        let outterShadowOpacity = colorScheme == .dark ? 0.8 : 0.0
        let cornerRadius: CGFloat = 8
        
        configuration.label
            .font(.system(size: 13, weight: .light, design: .default))
            .foregroundColor(.primary)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius,
                                 style: .continuous)
                .fill(color)
                .shadow(color: .black.opacity(0.1), radius: 0.1, x: 0, y: 1)
                .shadow(color: .primary.opacity(outterShadowOpacity), radius: 0.1, x: 0, y: -0.6))
        
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1))
    }
}
