//
//  SnippetTableCellView.swift
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

import Cocoa

final class SnippetTableCellView: NSTableCellView {
    @IBOutlet weak var titleTextField: NSTextField!
    @IBOutlet weak var snippetTextField: NSTextField!
    @IBOutlet weak var urlTextField: NSTextField!
    @IBOutlet weak var faviconImageView: NSImageView!

    override var objectValue: Any? {
        didSet {
            guard let some = objectValue else { return }
            guard let model = some as? SearchResult else { fatalError("Unexpected object value") }
            display(model)
        }
    }

    func display(_ model: SearchResult) {
        if !model.title.isEmpty {
            titleTextField.stringValue = model.title
            titleTextField.isHidden = false
        } else {
            titleTextField.isHidden = true
        }
        if let snippet = model.snippet,
           !snippet.isEmpty {
            snippetTextField.stringValue = snippet
            snippetTextField.isHidden = false
        } else {
            snippetTextField.isHidden = true
        }

        let url = model.url?.redirectLink.flatMap(URL.init(string:)) ?? model.url
        if let url = url, url.scheme != "file" {
            urlTextField.stringValue = url.absoluteString
            urlTextField.isHidden = false
        } else {
            urlTextField.isHidden = true
        }

        if let image = model.favicon {
            self.faviconImageView.image = image
        } else if url?.host != nil || model.faviconURL?.host != nil {
            LocalFaviconService.shared.fetchFavicon(model.faviconURL,
                                                    for: url?.host ?? model.faviconURL!.host!,
                                                    isFromUserScript: false) { [weak self] (image, _) in
                dispatchPrecondition(condition: .onQueue(.main))
                guard let self = self,
                      self.objectValue as? SearchResult == model
                else { return }

                self.faviconImageView.image = image
            }
        }
    }

}
