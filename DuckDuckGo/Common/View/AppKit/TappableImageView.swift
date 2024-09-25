//
//  TappableImageView.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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

final class TappableImageView: NSImageView {
    var onClick: (() -> Void)?

    /// We do not call super.mouseDown(with: event) because we do not want to trigger a mouseDown event on any of the super views.
    ///
    /// For example, when the audio button on tabs is tapped we do not want the tab to be selected if it is not.
    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
