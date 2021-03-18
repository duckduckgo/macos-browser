//
//  DefaultBrowserPromptView.swift
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

import AppKit

protocol DefaultBrowserPromptViewDelegate: class {
    func defaultBrowserPromptViewDismissed(_ view: DefaultBrowserPromptView)
    func defaultBrowserPromptViewRequestedDefaultBrowserPrompt(_ view: DefaultBrowserPromptView)
}

final class DefaultBrowserPromptView: NSView, NibLoadable {

    @IBOutlet var logoImageView: NSImageView! {
        didSet {
            logoImageView.wantsLayer = true
            logoImageView.layer?.masksToBounds = false
            logoImageView.layer?.shadowOpacity = 0.20
            logoImageView.layer?.shadowColor = NSColor.black.cgColor
            logoImageView.layer?.shadowOffset = CGSize(width: 0, height: -1)
            logoImageView.layer?.shadowRadius = 2
        }
    }

    weak var delegate: DefaultBrowserPromptViewDelegate?

    @IBAction func setDefaultButtonClicked(_ sender: Any) {
        delegate?.defaultBrowserPromptViewRequestedDefaultBrowserPrompt(self)
    }

    @IBAction func dismissPromptButtonClicked(_ sender: Any) {
        delegate?.defaultBrowserPromptViewDismissed(self)
    }

}
