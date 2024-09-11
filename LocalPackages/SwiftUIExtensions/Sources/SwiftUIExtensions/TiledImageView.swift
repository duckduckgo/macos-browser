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
