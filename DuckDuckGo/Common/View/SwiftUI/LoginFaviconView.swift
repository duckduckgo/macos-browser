//
//  LoginFaviconView.swift
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
import BrowserServicesKit

struct LoginFaviconView: View {
    let domain: String
    let preferredFirstCharacter: String?
    let preferredColor: Int = 1
    let faviconManagement: FaviconManagement = FaviconManager.shared

    var body: some View {
        if let image = faviconManagement.getCachedFavicon(for: domain, sizeCategory: .small)?.image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32)
                .cornerRadius(4.0)
                .padding(.leading, 6)
        } else {
            let domainFirst = String(domain.first ?? "#")
            let letter = preferredFirstCharacter ?? domainFirst
            AutofillIconLetterView(title: domain, prefferedFirstCharacter: letter)
        }
    }

    var favicon: NSImage? {
        return faviconManagement.getCachedFavicon(for: domain, sizeCategory: .small)?.image ?? NSImage(named: "Login")
    }

}
