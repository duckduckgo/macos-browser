//
//  TiledImageView.swift
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

public struct TiledImageView: View {
    public let image: Image
    public let tileSize: CGSize

    public init(image: Image, tileSize: CGSize) {
        self.image = image
        self.tileSize = tileSize
    }

    public var body: some View {
        GeometryReader { geometry in
            let rows = Int(ceil(geometry.size.height / tileSize.height))
            let columns = Int(ceil(geometry.size.width / tileSize.width))
            createTiledImage(rows: rows, columns: columns)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
    }

    private func createTiledImage(rows: Int, columns: Int) -> some View {
        /// Using ScrollView with LazyVStack and LazyHStack for performance benefits
        /// when rendering a large number of tiles.
        ScrollView([.vertical, .horizontal], showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { _ in
                    LazyHStack(spacing: 0) {
                        ForEach(0..<columns, id: \.self) { _ in
                            self.image
                                .resizable()
                                .frame(width: tileSize.width, height: tileSize.height)
                        }
                    }
                }
            }
        }
        .disabled(true)
    }
}
