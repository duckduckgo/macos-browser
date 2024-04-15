//
//  TieredDialogView.swift
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

import SwiftUI

/// A view to arrange its subviews in a three vertical sections separated by dividers.
public struct TieredDialogView<Top: View, Center: View, Bottom: View>: View {
    private let verticalSpacing: CGFloat
    private let horizontalAlignment: HorizontalAlignment
    private let horizontalPadding: CGFloat?
    @ViewBuilder private let top: () -> Top
    @ViewBuilder private let center: () -> Center
    @ViewBuilder private let bottom: () -> Bottom

    /// Creates an instance with the given vertical spacing, horizontal alignment, horizontal padding and views created by the specified view builders.
    /// - Parameters:
    ///   - verticalSpacing: The distance between adjacent sections.
    ///   - horizontalAlignment: The guide for aligning the sections in the vertical stack. This guide has the same vertical screen coordinate for every subview.
    ///   - horizontalPadding: The padding amount to add to the horizontal edges of the sections.
    ///   - top: A view builder that creates the content of the top section of the dialog.
    ///   - center: A view builder that creates the content of the central section of the dialog.
    ///   - bottom: A view builder that creates the content of the bottom section of the dialog.
    public init(
        verticalSpacing: CGFloat = 10.0,
        horizontalAlignment: HorizontalAlignment = .leading,
        horizontalPadding: CGFloat? = nil,
        @ViewBuilder top: @escaping () -> Top,
        @ViewBuilder center: @escaping () -> Center,
        @ViewBuilder bottom: @escaping () -> Bottom
    ) {
        self.horizontalAlignment = horizontalAlignment
        self.verticalSpacing = verticalSpacing
        self.horizontalPadding = horizontalPadding
        self.top = top
        self.center = center
        self.bottom = bottom
    }

    public var body: some View {
        VStack(alignment: horizontalAlignment, spacing: verticalSpacing) {
            top()
                .padding(.horizontal, horizontalPadding)

            Divider()

            center()
                .padding(.horizontal, horizontalPadding)

            Divider()

            bottom()
                .padding(.horizontal, horizontalPadding)
        }
    }
}
