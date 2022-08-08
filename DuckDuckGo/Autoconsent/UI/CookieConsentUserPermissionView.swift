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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 32) {
                HStack(alignment: .top, spacing: 0) {
                    daxStackView
                        .frame(width: Consts.Layout.daxContainerWidth)
                    contentView
                }
                .frame(height: Consts.Layout.innerContainerHeight)
                buttonStack
            }
            .frame(width: Consts.Layout.outerContainerWidth)
        }
        .padding(Consts.Layout.containerPadding)
        .background(Color("CookieConsentPanelBackground"))
        .cornerRadius(Consts.Layout.containerCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Consts.Layout.containerCornerRadius)
                .stroke(colorScheme == .dark ? Consts.Colors.darkModeBorderColor : Consts.Colors.whiteModeBorderColor, lineWidth: 1)
        )
    }
  
    private var daxStackView: some View {
        VStack {
            HStack {
                Image("OnboardingDax")
                    .resizable()
                    .frame(width: Consts.Layout.daxImageSize, height: Consts.Layout.daxImageSize)
                    .shadow(color: Consts.Colors.daxShadow, radius: 6, x: 0, y: 3)
                
                Spacer()
            }
        }
    }
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(UserText.autoconsentModalTitle)
                .font(.system(size: Consts.Font.size))
                .fontWeight(.light)
            
            CookieConsentAnimationView(animationModel: sketchAnimationModel)
                .padding(.leading, 40)
            
            Text(UserText.autoconsentModalBody)
                .fontWeight(.light)
                .font(.system(size: Consts.Font.size))
            
        }.frame(maxHeight: .infinity)
    }
    
    private var buttonStack: some View {
        HStack {
            Button {
                result(false)
            } label: {
                Text(UserText.autoconsentModalDenyButton)
            }
            .buttonStyle(SecondaryCTAStyle())
            
            Button {
                result(true)
            } label: {
                Text(UserText.autoconsentModalConfirmButton)
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
        
        CookieConsentUserPermissionView(sketchAnimationModel: CookieConsentAnimationMock(), result: result).preferredColorScheme(.dark)
            .padding()
        CookieConsentUserPermissionView(sketchAnimationModel: CookieConsentAnimationMock(), result: result).preferredColorScheme(.light)
            .padding()
    }
}

private struct PrimaryCTAStyle: ButtonStyle {
    
    func makeBody(configuration: Self.Configuration) -> some View {

        let color = configuration.isPressed ? Color("CookieConsentPrimaryButtonPressed") : Color("CookieConsentPrimaryButton")

        configuration.label
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .truncationMode(.tail)
            .background(RoundedRectangle(cornerRadius: Consts.Layout.CTACornerRadius, style: .continuous).fill(color))
            .foregroundColor(.white)
            .font(.system(size: 13, weight: .light, design: .default))
    }
}

private struct SecondaryCTAStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Self.Configuration) -> some View {
        
        let color = configuration.isPressed ? Color("CookieConsentSecondaryButtonPressed") : Color("CookieConsentSecondaryButton")
        
        let outterShadowOpacity = colorScheme == .dark ? 0.8 : 0.0
        
        configuration.label
            .font(.system(size: 13, weight: .light, design: .default))
            .foregroundColor(.primary)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Consts.Layout.CTACornerRadius, style: .continuous)
                .fill(color)
                .shadow(color: .black.opacity(0.1), radius: 0.1, x: 0, y: 1)
                .shadow(color: .primary.opacity(outterShadowOpacity), radius: 0.1, x: 0, y: -0.6))
        
            .overlay(
                RoundedRectangle(cornerRadius: Consts.Layout.CTACornerRadius)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1))
    }
}

private enum Consts {
    struct Layout {
        static let outerContainerWidth: CGFloat = 490
        static let daxContainerWidth: CGFloat = 84
        static let innerContainerHeight: CGFloat = 176
        static let daxImageSize: CGFloat = 64
        static let containerCornerRadius: CGFloat = 12
        static let CTACornerRadius: CGFloat = 8
        static let containerPadding: CGFloat = 20
    }
    
    struct Colors {
        static let darkModeBorderColor: Color = .white.opacity(0.2)
        static let whiteModeBorderColor: Color = .black.opacity(0.1)
        static let daxShadow: Color = .black.opacity(0.16)
    }
    struct Font {
        static let size: CGFloat = 15
    }
}
