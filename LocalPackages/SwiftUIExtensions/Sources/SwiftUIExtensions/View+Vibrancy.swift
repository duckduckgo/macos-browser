//
//  View+Vibrancy.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var alpha: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.alphaValue = alpha
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
        nsView.alphaValue = alpha
        nsView.isEmphasized = true
    }
}

public extension View {
    /**
     * Displays `cursor` when the view is hovered.
     *
     * This modifier uses `.onHover` under the hood, so it takes an optional
     * closure parameter that would be called inside the `.onHover` modifier
     * before updating the cursor, removing the need to add a separate `.onHover`
     * modifier.
     */
    func vibrancyEffect(
        useLegacyBlur: Bool,
        material: VibrancyMaterial,
        legacyMaterial: NSVisualEffectView.Material = .fullScreenUI,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow,
        alpha: CGFloat = 1.0
    ) -> some View {
        modifier(VibrancyModifier(useLegacyBlur: useLegacyBlur, material: material, legacyMaterial: legacyMaterial, blendingMode: blendingMode, alpha: alpha))
    }
}

public enum VibrancyMaterial {
    case regular
    case thickMaterial
    case thinMaterial
    case ultraThinMaterial
    case ultraThickMaterial

    @available(macOS 12.0, *)
    var material: Material {
        switch self {
        case .regular:
                .regular
        case .thickMaterial:
                .thickMaterial
        case .thinMaterial:
                .thinMaterial
        case .ultraThinMaterial:
                .ultraThinMaterial
        case .ultraThickMaterial:
                .ultraThickMaterial
        }
    }
}

private struct VibrancyModifier: ViewModifier {

    let useLegacyBlur: Bool
    let material: VibrancyMaterial
    let legacyMaterial: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let alpha: CGFloat
//    let color: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if useLegacyBlur {
            content.background(VisualEffectBlur(material: legacyMaterial, blendingMode: blendingMode, alpha: alpha))
        } else {
            if #available(macOS 12.0, *) {
                content.background(material.material.opacity(alpha))
            } else {
                content.background(Color.white)
            }
        }
    }
}
