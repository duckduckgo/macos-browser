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
import SwiftUIExtensions

struct FaviconView: View {

    let faviconManagement: FaviconManagement = FaviconManager.shared

    let url: URL?
    let size: CGFloat
    let onFaviconMissing: (() -> Void)?
    private var letterPaddingModifier: CGFloat

    var domain: String {
        url?.host ?? ""
    }

    @State var image: NSImage?
    @State private var timer = Timer.publish(every: 0.1, tolerance: 0, on: .main, in: .default, options: nil).autoconnect()

    /// Initializes a `FaviconView`
    /// Note: The `letterPaddingModifier` parameter is only used when a `LetterIconView` is displayed instead of a Favicon image
    init(url: URL?, size: CGFloat = 32, letterPaddingModifier: CGFloat = 0.33, onFaviconMissing: (() -> Void)? = nil) {
        self.url = url
        self.size = size
        self.letterPaddingModifier = letterPaddingModifier
        self.onFaviconMissing = onFaviconMissing
    }

    @MainActor(unsafe)
    func refreshImage() {
        if let duckPlayerImage = DuckPlayer.shared.image(for: self) {
            image = duckPlayerImage
            return
        }

        if faviconManagement.areFaviconsLoaded, let url = url {
            let image = faviconManagement.getCachedFavicon(for: url, sizeCategory: .medium)?.image
            if image?.size.isSmaller(than: CGSize(width: 16, height: 16)) == false {
                self.image = image
                return
            }
            onFaviconMissing?()
        }

        image = nil
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
                LetterIconView(title: ContentBlocking.shared.tld.eTLDplus1(domain) ?? domain, size: size, paddingModifier: letterPaddingModifier)
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
