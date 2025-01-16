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
import SwiftUIExtensions

enum GradientBackground: String, Equatable, Identifiable, CaseIterable, ColorSchemeProviding, CustomBackgroundConvertible {
    var id: Self {
        self
    }

    case gradient01
    case gradient02
    case gradient0201 = "gradient02.01"
    case gradient03
    case gradient04
    case gradient05
    case gradient06
    case gradient07

    @ViewBuilder
    var view: some View {
        TiledImageView(image: Image(nsImage: .homePageBackgroundGradientGrain), tileSize: CGSize(width: 100, height: 100)).opacity(0.15)
            .background(gradientImage)
    }

    @ViewBuilder
    private var gradientImage: some View {
        if #available(macOS 12.0, *) {
            switch self {
            case .gradient01:
                Gradient01()
            case .gradient02:
                Gradient02()
            case .gradient0201:
                Gradient0201()
            case .gradient03:
                Gradient03()
            case .gradient04:
                Gradient04()
            case .gradient05:
                Gradient05()
            case .gradient06:
                Gradient06()
            case .gradient07:
                Gradient07()
            }
        } else {
            image.resizable().scaledToFill()
        }
    }

    var image: Image {
        switch self {
        case .gradient01:
            Image(nsImage: .homePageBackgroundGradient01)
        case .gradient02:
            Image(nsImage: .homePageBackgroundGradient02)
        case .gradient0201:
            Image(nsImage: .homePageBackgroundGradient0201)
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
        case .gradient01, .gradient02, .gradient0201, .gradient03:
                .light
        case .gradient04, .gradient05, .gradient06, .gradient07:
                .dark
        }
    }

    var customBackground: CustomBackground {
        .gradient(self)
    }
}

// MARK: - Gradient views definition

/**
 * The views below are gradients implemented in SwiftUI.
 * The code is imported from Figma, not written by hand.
 */

@available(macOS 12.0, *)
private struct Gradient01: View {
    var body: some View {
        ZStack {
            EllipticalGradient(
                colors: [Color(red: 1, green: 0.84, blue: 0.36).opacity(0.6), .clear],
                center: UnitPoint(x: -0.14, y: -0.1),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.92, green: 0.53, blue: 0.42).opacity(0.4), .clear],
                center: UnitPoint(x: 1.03, y: 0.38),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.97, green: 0.73, blue: 0.67).opacity(0.6), .clear],
                center: UnitPoint(x: 1.05, y: 0.21),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.95, green: 0.63, blue: 0.54).opacity(0.6), .clear],
                center: UnitPoint(x: -0.26, y: 0.5),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 1, green: 0.94, blue: 0.76).opacity(0.8), .clear],
                center: UnitPoint(x: 0.98, y: 1.17),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [.white.opacity(0.4), .clear],
                center: UnitPoint(x: 0.47, y: 0.41),
                endRadiusFraction: 1
            )
        }
        .background(.white)
    }
}

@available(macOS 12.0, *)
private struct Gradient02: View {
    var body: some View {
        ZStack {
            EllipticalGradient(
                colors: [Color(red: 1, green: 0.84, blue: 0.8), .clear],
                center: UnitPoint(x: 0, y: 0.72),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.78, green: 0.73, blue: 0.93), .clear],
                center: UnitPoint(x: 0.89, y: -0.09),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 1, green: 0.84, blue: 0.8).opacity(0.6), .clear],
                center: UnitPoint(x: 0.83, y: 1.12),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.8, green: 0.85, blue: 1), .clear],
                center: UnitPoint(x: 1.05, y: 0.37),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.65, green: 0.57, blue: 0.86).opacity(0.7), .clear],
                center: UnitPoint(x: -0.06, y: -0.02),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [.white.opacity(0.4), .clear],
                center: UnitPoint(x: 0.57, y: 0.6),
                endRadiusFraction: 1
            )

        }
        .background(.white)
    }
}

@available(macOS 12.0, *)
private struct Gradient0201: View {
    var body: some View {
        ZStack {
            EllipticalGradient(
                colors: [Color(red: 1, green: 0.8, blue: 0.2).opacity(0.8), .clear],
                center: UnitPoint(x: 1.04, y: 1.08),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [
                    Color(red: 1, green: 0.84, blue: 0.36).opacity(0.7),
                    Color(red: 1, green: 0.84, blue: 0.8).opacity(0.2)
                ],
                center: UnitPoint(x: 0.56, y: 0.5),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.95, green: 0.63, blue: 0.54).opacity(0.6), .clear],
                center: UnitPoint(x: -0.26, y: 0.5),
                endRadiusFraction: 1
            )
        }
        .background(Color(red: 1, green: 0.87, blue: 0.48))
    }
}

@available(macOS 12.0, *)
private struct Gradient03: View {
    var body: some View {
        ZStack {
            EllipticalGradient(
                colors: [Color(red: 0.87, green: 0.35, blue: 0.2).opacity(0.8), .clear],
                center: UnitPoint(x: 0.58, y: 0.13),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.32, green: 0.2, blue: 0.66).opacity(0.8), .clear],
                center: UnitPoint(x: 0.96, y: 1.18),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 1, green: 0.8, blue: 0.2).opacity(0.8), .clear],
                center: UnitPoint(x: -0.07, y: 0.63),
                endRadiusFraction: 1
            )
        }
        .background(Color(red: 1, green: 0.84, blue: 0.8))
    }
}

@available(macOS 12.0, *)
private struct Gradient04: View {
    var body: some View {
        ZStack {
            EllipticalGradient(
                colors: [Color(red: 0.24, green: 0.13, blue: 0.55).opacity(0.8), .clear],
                center: UnitPoint(x: 0.65, y: 1.19),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.24, green: 0.13, blue: 0.55).opacity(0.4), .clear],
                center: UnitPoint(x: 0.63, y: 1.2),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.12, green: 0.26, blue: 0.64).opacity(0.8), .clear],
                center: UnitPoint(x: -0.07, y: 1.09),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.53, green: 0.43, blue: 0.8).opacity(0.8), .clear],
                center: UnitPoint(x: 0.77, y: -0.15),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.53, green: 0.43, blue: 0.8).opacity(0.6), .clear],
                center: UnitPoint(x: 1.04, y: 0.07),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.92, green: 0.53, blue: 0.42).opacity(0.8), .clear],
                center: UnitPoint(x: 1.04, y: 0.04),
                endRadiusFraction: 1
            )
        }
        .background(Color(red: 0.33, green: 0.5, blue: 0.95))
    }
}

@available(macOS 12.0, *)
private struct Gradient05: View {
    var body: some View {
        ZStack {
            EllipticalGradient(
                colors: [Color(red: 0.53, green: 0.43, blue: 0.8).opacity(0.8), .clear],
                center: UnitPoint(x: -0.02, y: 1),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.87, green: 0.35, blue: 0.2).opacity(0.8), .clear],
                center: UnitPoint(x: 0.67, y: -0.06),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.87, green: 0.35, blue: 0.2).opacity(0.8), .clear],
                center: UnitPoint(x: 1.02, y: 0.14),
                endRadiusFraction: 1
            )
        }
        .background(Color(red: 0.32, green: 0.2, blue: 0.66))
    }
}

@available(macOS 12.0, *)
private struct Gradient06: View {
    var body: some View {
        ZStack {
            EllipticalGradient(
                colors: [Color(red: 0.07, green: 0.01, blue: 0.21).opacity(0.8), .clear],
                center: UnitPoint(x: -0.03, y: -0.08),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.17, green: 0.08, blue: 0.44).opacity(0.6), .clear],
                center: UnitPoint(x: 0.71, y: -0.41),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.92, green: 0.53, blue: 0.42).opacity(0.8), .clear],
                center: UnitPoint(x: 0.76, y: -0.37),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.04, green: 0.13, blue: 0.35).opacity(0.8), .clear],
                center: UnitPoint(x: 0.17, y: -0.19),
                endRadiusFraction: 1
            )

            Color(red: 0.03, green: 0, blue: 0.1, opacity: 0.5)
        }
        .background(Color(red: 0.07, green: 0.01, blue: 0.21))
    }
}

@available(macOS 12.0, *)
private struct Gradient07: View {
    var body: some View {
        ZStack {
            EllipticalGradient(
                colors: [Color(red: 0.17, green: 0.08, blue: 0.4).opacity(0.8), .clear],
                center: UnitPoint(x: 0.97, y: 1.11),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.24, green: 0.13, blue: 0.55).opacity(0.7), .clear],
                center: UnitPoint(x: 0.05, y: 1.24),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.53, green: 0.43, blue: 0.8).opacity(0.8), .clear],
                center: UnitPoint(x: 0.94, y: -0.1),
                endRadiusFraction: 1
            )

            EllipticalGradient(
                colors: [Color(red: 0.87, green: 0.35, blue: 0.2).opacity(0.8), .clear],
                center: UnitPoint(x: 1, y: -0.08),
                endRadiusFraction: 1
            )
        }
        .background(Color(red: 0.03, green: 0, blue: 0.1))
    }
}

#Preview {
    VStack(spacing: 0) {
        GradientBackground.gradient01.view
            .frame(width: 640, height: 400)
        GradientBackground.gradient02.view
            .frame(width: 640, height: 400)
        GradientBackground.gradient0201.view
            .frame(width: 640, height: 400)
        GradientBackground.gradient03.view
            .frame(width: 640, height: 400)
        GradientBackground.gradient04.view
            .frame(width: 640, height: 400)
        GradientBackground.gradient05.view
            .frame(width: 640, height: 400)
        GradientBackground.gradient06.view
            .frame(width: 640, height: 400)
        GradientBackground.gradient07.view
            .frame(width: 640, height: 400)
    }
}
