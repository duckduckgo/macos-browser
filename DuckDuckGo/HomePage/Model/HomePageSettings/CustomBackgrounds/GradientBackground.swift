//
//  GradientBackground.swift
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

import AppKit
import SwiftUI

enum GradientBackground: String, Equatable, Identifiable, CaseIterable, ColorSchemeProviding, CustomBackgroundConvertible {
    var id: Self {
        self
    }

    case gradient01
    case gradient02
    case gradient03
    case gradient04
    case gradient05
    case gradient06
    case gradient07

    struct Constants {
        static let ColorSystemPurple100: Color = Color(.sRGB, red: 0.03, green: 0, blue: 0.1)
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .gradient07:
            if #available(macOS 12.0, *) {
                ZStack {
                    // background: radial-gradient(92.44% 78.41% at 96.76% 110.91%, rgba(44, 20, 102, 0.80) 0%, rgba(44, 20, 111, 0.00) 100%);
                    EllipticalGradient(
                        colors: [Color(red: 44/255.0, green: 20/255.0, blue: 102/255.0).opacity(0.8), .clear],
                        center: UnitPoint(x: 0.9676, y: 1.1091),
                        endRadiusFraction: 1
                    )

                    // background: radial-gradient(128.38% 142.82% at 4.57% 123.78%, rgba(62, 34, 140, 0.70) 0%, rgba(44, 20, 111, 0.00) 100%);
                    EllipticalGradient(
                        colors: [Color(red: 0.24, green: 0.13, blue: 0.55).opacity(0.7), .clear],
                        center: UnitPoint(x: 0.05, y: 1.24),
                        endRadiusFraction: 1
                    )

                    // background: radial-gradient(136.09% 142.11% at 94.26% -10.49%, rgba(135, 110, 203, 0.80) 0%, rgba(44, 20, 111, 0.00) 100%);
                    EllipticalGradient(
                        colors: [Color(red: 0.53, green: 0.43, blue: 0.8).opacity(0.8), .clear],
                        center: UnitPoint(x: 0.94, y: -0.1),
                        endRadiusFraction: 1
                    )

                    // background: radial-gradient(117.73% 115.54% at 100% -8.25%, rgba(222, 88, 51, 0.80) 0%, rgba(44, 20, 111, 0.00) 100%);
                    EllipticalGradient(
                        colors: [Color(red: 0.87, green: 0.35, blue: 0.2).opacity(0.8), .clear],
                        center: UnitPoint(x: 1, y: -0.08),
                        endRadiusFraction: 1
                    )
                }
                .background(Constants.ColorSystemPurple100)
            } else {
                image.resizable().scaledToFill()
            }
        default:
            image.resizable().scaledToFill()
        }
    }

    var image: Image {
        switch self {
        case .gradient01:
            Image(nsImage: .homePageBackgroundGradient01)
        case .gradient02:
            Image(nsImage: .homePageBackgroundGradient02)
        case .gradient03:
            Image(nsImage: .homePageBackgroundGradient03)
        case .gradient04:
            Image(nsImage: .homePageBackgroundGradient04)
        case .gradient05:
            Image(nsImage: .homePageBackgroundGradient05)
        case .gradient06:
            Image(nsImage: .homePageBackgroundGradient06)
        case .gradient07:
            Image(nsImage: .homePageBackgroundGradient07)
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .gradient01, .gradient02, .gradient03:
                .light
        case .gradient04, .gradient05, .gradient06, .gradient07:
                .dark
        }
    }

    var customBackground: CustomBackground {
        .gradient(self)
    }
}

#Preview {
    GradientBackground.gradient07.view
        .frame(width: 640, height: 400)
}
