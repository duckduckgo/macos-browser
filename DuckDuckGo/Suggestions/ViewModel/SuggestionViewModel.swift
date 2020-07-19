//
//  SuggestionViewModel.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
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

class SuggestionViewModel {

    let suggestion: Suggestion

    init(suggestion: Suggestion) {
        self.suggestion = suggestion
    }

    var attributedString: NSAttributedString {
        let firstAttributes = [NSAttributedString.Key.foregroundColor: NSColor.labelColor]
        let secondAttributes = [NSAttributedString.Key.foregroundColor: NSColor.secondaryLabelColor]

        switch suggestion {
        case .phrase(phrase: let phrase):
            let firstPart = NSMutableAttributedString(string: phrase, attributes: firstAttributes)
            let secondPart = NSAttributedString(string: " - DuckDuckGo Search", attributes: secondAttributes)
            firstPart.append(secondPart)
            return firstPart
        case .website(url: let url, title: let title):
            if let title = title {
                let firstPart = NSMutableAttributedString(string: title, attributes: firstAttributes)
                let secondPart = NSAttributedString(string: " - \(url.absoluteString)", attributes: secondAttributes)
                firstPart.append(secondPart)
                return firstPart
            } else {
                return NSAttributedString(string: "\(url.absoluteString)", attributes: firstAttributes)
            }
        case .unknown(value: let value):
            return NSAttributedString(string: value, attributes: firstAttributes)
        }
    }

    var icon: NSImage? {
        switch suggestion {
        case .phrase(phrase: _):
            return NSImage(named: "NSTouchBarSearchTemplate")
        case .website(url: _, title: _):
            return NSImage(named: "NSListViewTemplate")
        case .unknown(value: _):
            return NSImage(named: "NSListViewTemplate")
        }
    }

}
