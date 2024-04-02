//
//  TwoColumnsListView.swift
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

/// A view to arrange its subviews in two-column equally spaced rows.
public struct TwoColumnsListView<Left: View, Right: View>: View {
    private let rowHeight: CGFloat?
    private let horizontalSpacing: CGFloat?
    private let verticalSpacing: CGFloat?
    @ViewBuilder private let leftColumn: () -> Left
    @ViewBuilder private let rightColumn: () -> Right

    /// Creates an instance with the given horizontal and vertical spacing, row height and
    /// - Parameters:
    ///   - horizontalSpacing: The horizontal distance between adjacent subviews.
    ///   - verticalSpacing: The vertical distance between adjacent subviews.
    ///   - rowHeight: The height of the rows in the stack.
    ///   - leftColumn: A view builder that creates the content of the left section of the view.
    ///   - rightColumn: A view builder that creates the content of the right section of the view.
    public init(
        horizontalSpacing: CGFloat? = nil,
        verticalSpacing: CGFloat? = nil,
        rowHeight: CGFloat? = nil,
        @ViewBuilder leftColumn: @escaping () -> Left,
        @ViewBuilder rightColumn: @escaping () -> Right
    ) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.rowHeight = rowHeight
        self.leftColumn = leftColumn
        self.rightColumn = rightColumn
    }

    public var body: some View {
        HStack(alignment: .center, spacing: horizontalSpacing) {
            VStack(alignment: .leading, spacing: verticalSpacing) {
                leftColumn()
                    .frame(height: rowHeight)
            }
            VStack(alignment: .leading, spacing: verticalSpacing) {
                rightColumn()
                    .frame(height: rowHeight)
            }
        }
    }
}
