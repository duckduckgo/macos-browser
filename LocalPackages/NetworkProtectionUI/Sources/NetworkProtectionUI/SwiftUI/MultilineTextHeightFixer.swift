//
//  File.swift
//  
//
//  Created by ddg on 03/08/2023.
//

import Foundation
import SwiftUI

/// Fixes the height for multiline text fields, which seem to suffer from a layout issue where
/// their height isn't properly honored.
///
private struct MultilineTextHeightFixer: ViewModifier {
    @State var textHeight: CGFloat?

    func body(content: Content) -> some View {
        content
            .frame(height: textHeight)
            .background(
                GeometryReader { proxy in
                    Color.clear // This is just to have something to attach .onAppear to.
                        .onAppear {
                            textHeight = proxy.size.height
                        }
                })
    }
}

extension View {
    /// Meant to be used for multiline-text.  This is currently only applying a modifier
    ///
    @ViewBuilder
    func multilineText() -> some View {
        self.fixedSize(horizontal: false, vertical: true)
            .modifier(MultilineTextHeightFixer())
    }
}
