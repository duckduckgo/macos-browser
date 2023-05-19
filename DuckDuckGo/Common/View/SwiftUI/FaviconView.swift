//
//  FaviconView.swift
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

struct FaviconView: View {

    let faviconManagement: FaviconManagement = FaviconManager.shared

    let domain: String
    let size: CGFloat

    @State var image: NSImage?
    @State private var timer = Timer.publish(every: 0.1, tolerance: 0, on: .main, in: .default, options: nil).autoconnect()

    init(domain: String, size: CGFloat = 32) {
        self.domain = domain
        self.size = size
    }

    func refreshImage() {
        if let privatePlayerImage = PrivatePlayer.shared.image(for: self) {
            image = privatePlayerImage
            return
        }

        let image = faviconManagement.getCachedFavicon(for: domain, sizeCategory: .medium)?.image
        if image?.size.isSmaller(than: CGSize(width: 16, height: 16)) == false {
            self.image = image
        }
    }

    var body: some View {

        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .cornerRadius(4.0)
                    .onReceive(timer) { _ in
                        refreshImage()
                        timer.upstream.connect().cancel()
                    }
            } else {

                ZStack {
                    Rectangle()
                        .foregroundColor(Color.forDomain(domain.droppingWwwPrefix()))
                    Text(String(domain.droppingWwwPrefix().capitalized.first ?? "?"))
                        .font(.title)
                        .foregroundColor(Color.white)
                }
                .frame(width: size, height: size)
                .cornerRadius(4.0)

            }
        }.onAppear {
            refreshImage()
        }.onReceive(timer) { _ in
            guard faviconManagement.areFaviconsLoaded else { return }
            timer.upstream.connect().cancel()
            refreshImage()
        }

    }

}
