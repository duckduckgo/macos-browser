//
//  UrlEventListener.swift
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

import Foundation
import os.log

final class UrlEventListener {

    func listen() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleUrlEvent(event:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleUrlEvent(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let path = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue?.removingPercentEncoding,
              let url = URL(string: path) else {
            os_log("AppDelegate: URL initialization failed", type: .error)
            return
        }

        guard let windowController = WindowControllersManager.shared.lastKeyMainWindowController,
              windowController.window?.isKeyWindow == true else {
            WindowsManager.shared.openNewWindow(with: url)
            return
        }

        let tabCollectionViewModel = windowController.tabCollectionViewModel
        let tabCollection = tabCollectionViewModel.tabCollection

        if tabCollection.tabs.count == 1,
           let firstTab = tabCollection.tabs.first,
           firstTab.isHomepageLoaded {
            firstTab.url = url
        } else {
            let newTab = Tab()
            newTab.url = url
            tabCollectionViewModel.append(tab: newTab)
        }
    }

}
