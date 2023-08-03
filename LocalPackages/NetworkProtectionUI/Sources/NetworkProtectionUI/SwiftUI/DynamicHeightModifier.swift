//
//  File.swift
//  
//
//  Created by ddg on 03/08/2023.
//

import Foundation
import SwiftUI

struct DynamicHeightModifier: ViewModifier {
    @State var textHeight: CGFloat?

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .frame(height: textHeight)
            .background(
                GeometryReader { proxy in
                    Color.clear // we just want the reader to get triggered, so let's use an empty color
                        .onAppear {
                            textHeight = proxy.size.height
                        }
                })
    }
}

extension View {
    /// Meant to be used for multiline-text.  This fixes the height not being right when the text is being
    /// laid out if it ends up spanning multiple lines of height.
    ///
    @ViewBuilder
    func multilineText() -> some View {
        self.modifier(DynamicHeightModifier())
    }
}
