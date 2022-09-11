//
//  PaddedView.swift
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

import Foundation

final class PaddedView: NSView {
    
    private let subview: NSView
    private let padding: CGFloat
    
    init(frame: CGRect = .zero, view: NSView, padding: CGFloat, subviewSize: CGSize? = nil) {
        self.subview = view
        self.padding = padding

        super.init(frame: frame)
        
        self.addSubview(view)

        self.translatesAutoresizingMaskIntoConstraints = false
        view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: self.topAnchor, constant: padding),
            view.leftAnchor.constraint(equalTo: self.leftAnchor, constant: padding),
            view.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -padding),
            view.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -padding)
        ])
        
        if let subviewSize = subviewSize {
            NSLayoutConstraint.activate([
                view.widthAnchor.constraint(equalToConstant: subviewSize.width),
                view.heightAnchor.constraint(equalToConstant: subviewSize.height)
            ])
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: NSSize {
        return NSSize(
            width: self.subview.intrinsicContentSize.width + padding,
            height: self.subview.intrinsicContentSize.height + padding
        )
    }
    
}
