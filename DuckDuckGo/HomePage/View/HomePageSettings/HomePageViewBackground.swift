//
//  HomePageViewBackground.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

import SwiftUIExtensions

extension View {

    /**
     * This view modifier applies background to New Tab Page views when custom background is active.
     *
     * Some custom backgrounds use vibrancy effect, and some others use background color.
     * This function applies correct background based on the provided `customBackground` argument.
     */
    func homePageViewBackground(_ customBackground: CustomBackground?) -> some View {
        modifier(HomePageElementBackgroundModifier(customBackground: customBackground))
    }

    /**
     * This view modifier applies fixed color scheme based on the `customBackground`.
     *
     * If the passed `customBackground` is not nil, this modifier takes background's associated
     * `colorScheme` and applies it to the view. Otherwise it returns an unmodified view.
     */
    func fixedColorScheme(for customBackground: CustomBackground?) -> some View {
        modifier(CustomBackgroundFixedColorScheme(customBackground: customBackground))
    }
}

private struct HomePageElementBackgroundModifier: ViewModifier {

    let customBackground: CustomBackground?

    @ViewBuilder
    func body(content: Content) -> some View {
        switch customBackground {
        case .userImage:
            content.vibrancyEffect()
        case .gradient(let gradient):
            content.background(Color.newTabPageElementsBackground.colorScheme(gradient.colorScheme))
        case .solidColor(let solidColor):
            content.background(Color.newTabPageElementsBackground.colorScheme(solidColor.colorScheme))
        case .none:
            content.background(Color.homeFavoritesBackground)
        }
    }
}

private struct CustomBackgroundFixedColorScheme: ViewModifier {

    let customBackground: CustomBackground?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let colorScheme = customBackground?.colorScheme {
            content.colorScheme(colorScheme)
        } else {
            content
        }
    }
}
