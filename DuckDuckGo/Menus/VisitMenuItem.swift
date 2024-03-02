//
//  VisitMenuItem.swift
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

import AppKit
import History

final class VisitMenuItem: NSMenuItem {

    convenience init(visitViewModel: VisitViewModel) {
        self.init(title: visitViewModel.titleTruncated,
                  action: #selector(AppDelegate.openVisit(_:)),
                  keyEquivalent: "")
        image = visitViewModel.smallFaviconImage?.resizedToFaviconSize()
        // Keep the reference to visit in order to use it for burning
        representedObject = visitViewModel.visit
    }

    var visit: Visit? {
        representedObject as? Visit
    }

}
