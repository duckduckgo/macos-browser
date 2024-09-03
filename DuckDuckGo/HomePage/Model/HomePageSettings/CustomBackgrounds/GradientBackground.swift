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

struct TiledImageView: View {
    let image: Image
    let tileSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            self.createTiledImage(in: geometry.size)
        }
    }

    private func createTiledImage(in size: CGSize) -> some View {
        let rows = Int(ceil(size.height / tileSize.height))
        let columns = Int(ceil(size.width / tileSize.width))

        return ForEach(0..<rows, id: \.self) { row in
            ForEach(0..<columns, id: \.self) { column in
                self.image
                    .resizable()
                    .frame(width: tileSize.width, height: tileSize.height)
                    .position(x: CGFloat(column) * tileSize.width + tileSize.width / 2,
                              y: CGFloat(row) * tileSize.height + tileSize.height / 2)
            }
        }
    }
}

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

    @ViewBuilder
    var view: some View {
        TiledImageView(image: Image(nsImage: .homePageBackgroundGradientGrain), tileSize: CGSize(width: 50, height: 50)).opacity(0.3)
            .background(image.resizable().scaledToFill())
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
