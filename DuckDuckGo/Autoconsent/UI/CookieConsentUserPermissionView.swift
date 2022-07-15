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

struct CookieConsentUserPermissionView<AnimationModel>: View where AnimationModel: CookieConsentAnimation {
    var sketchAnimationModel: AnimationModel
    let result: (Bool) -> Void
    
    var body: some View {
        Group {
            VStack(spacing: 32) {
                HStack(alignment: .top) {
                    daxStackView
                    
                    contentView
                        .frame(width: Consts.Layout.contentViewWidth)
                }
                .frame(height: Consts.Layout.innerContainerHeight)
                
                buttonStack
            }
            .frame(width: Consts.Layout.outerContainerWidth)
        }
        .padding()
        .background(Color("CookieConsentPanelBackground"))
        .cornerRadius(Consts.Layout.containerCornerRadius)
    }
    
    private var daxStackView: some View {
        VStack {
            HStack {
                Image("OnboardingDax")
                    .resizable()
                    .frame(width: Consts.Layout.daxImageSize, height: Consts.Layout.daxImageSize)
                    .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 3)
                
                Spacer()
            }
        }
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Looks like this site has a cookie consent pop-up 👇")
                .font(.system(size: Consts.Font.size))
                .fontWeight(.light)
            
            CookieConsentAnimationView(animationModel: sketchAnimationModel)
                .padding(.leading, 40)
            
            Text("Want me to handle these for you? I can try to minimize cookies, maximize privacy, and hide pop-ups like these.")
                .fontWeight(.light)
                .font(.system(size: Consts.Font.size))
            
        }.frame(maxHeight: .infinity)
    }
    
    private var buttonStack: some View {
        HStack {
            Button {
                result(false)
            } label: {
                Text("No Thanks")
            }
            .buttonStyle(SecondaryCTAStyle())
            
            Button {
                result(true)
            } label: {
                Text("Manage Cookie Pop-ups")
            }
            .buttonStyle(PrimaryCTAStyle())
        }
    }
    
    func startAnimation() {
        sketchAnimationModel.startAnimation()
    }
}

struct CookieConsentUserPermissionView_Previews: PreviewProvider {
    static var previews: some View {
        let result: (Bool) -> Void = { _ in }
        
        if #available(macOS 11.0, *) {
            CookieConsentUserPermissionView(sketchAnimationModel: CookieConsentAnimationMock(), result: result).preferredColorScheme(.dark)
            CookieConsentUserPermissionView(sketchAnimationModel: CookieConsentAnimationMock(), result: result).preferredColorScheme(.light)
        } else {
            CookieConsentUserPermissionView(sketchAnimationModel: CookieConsentAnimationMock(), result: result)
        }
    }
}

private struct PrimaryCTAStyle: ButtonStyle {
    
    func makeBody(configuration: Self.Configuration) -> some View {

        let color = configuration.isPressed ? Color("CookieConsentPrimaryButtonPressed") : Color("CookieConsentPrimaryButton")

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
        
        let color = configuration.isPressed ? Color("CookieConsentSecondaryButtonPressed") : Color("CookieConsentSecondaryButton")
        
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

private enum Consts {
    struct Layout {
        static let outerContainerWidth: CGFloat = 490
        static let contentViewWidth: CGFloat = 406
        static let innerContainerHeight: CGFloat = 176
        static let daxImageSize: CGFloat = 64
        static let containerCornerRadius: CGFloat = 8
    }
    
    struct Font {
        static let size: CGFloat = 15
    }
}
