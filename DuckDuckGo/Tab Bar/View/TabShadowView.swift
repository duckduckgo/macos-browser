//
//  TabShadowView.swift
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

import Cocoa

final class TabShadowView: NSView {
    private lazy var shadowLine: NSView = {
        let view = NSView(frame: .zero)
        view.wantsLayer = true
        view.alphaValue = CGFloat(TabShadowConfig.alpha)
        return view
    }()

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
        
    override func updateLayer() {
        super.updateLayer()
    }
    
    private func setupSubviews() {
        addSubview(shadowLine)
    }
    
    override func layout() {
        super.layout()
        shadowLine.wantsLayer = true
        shadowLine.layer?.backgroundColor = NSColor(named: TabShadowConfig.colorName)?.cgColor
        shadowLine.frame = CGRect(x: 0, y: 2, width: frame.width, height: TabShadowConfig.dividerSize)
    }
}
