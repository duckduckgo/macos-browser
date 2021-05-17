//
//  OutlineSeparatorViewCell.swift
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

import Foundation

final class OutlineSeparatorViewCell: NSTableCellView {

    private lazy var separatorView: NSBox = {
        let box = NSBox()
        box.translatesAutoresizingMaskIntoConstraints = false
        box.boxType = .separator

        return box
    }()

    init(separatorVisible: Bool = false) {
        super.init(frame: .zero)

        self.heightAnchor.constraint(equalToConstant: 20).isActive = true

        if separatorVisible {
            addSubview(separatorView)

            separatorView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5).isActive = true
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
            separatorView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
