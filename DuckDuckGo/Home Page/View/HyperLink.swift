//
//  HyperLink.swift
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

import SwiftUI

// swiftlint:disable:next identifier_name
func HyperLink(_ text: String, textColor: Color, _ action: @escaping () -> Void) -> some View {
    TextButton(text, color: textColor, hoverColor: Color("LinkBlueColor"), underlineOnHover: true, action: action)
}
