//
//  SharingMenu.swift
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

final class SharingMenu: NSMenu {

    override func update() {
        self.removeAllItems()
        self.autoenablesItems = false

        let isEnabled = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController
            .tabCollectionViewModel.selectedTabViewModel?.canReload ?? false

        // not real sharing URL, used for generating items for NSURL
        let services = NSSharingService.sharingServices(forItems: [URL.duckDuckGo])
        for service in services {
            let menuItem = NSMenuItem(service: service)
            menuItem.target = self
            menuItem.action = #selector(sharingItemSelected(_:))
            menuItem.isEnabled = isEnabled
            self.addItem(menuItem)
        }

        let moreItem = NSMenuItem(title: UserText.moreMenuItem,
                                  action: #selector(openSharingPreferences(_:)),
                                  keyEquivalent: "")
        moreItem.target = self
        moreItem.image = .more
        self.addItem(moreItem)
    }

    @objc func openSharingPreferences(_ sender: NSMenuItem) {
        let url = URL(fileURLWithPath: "/System/Library/PreferencePanes/Extensions.prefPane")
        let plist = [
            "action": "revealExtensionPoint",
            "protocol": "com.apple.share-services"
        ]
        let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let descriptor = NSAppleEventDescriptor(descriptorType: .openSharingSubpane, data: data)

        NSWorkspace.shared.open([url],
                                withAppBundleIdentifier: nil,
                                options: .async,
                                additionalEventParamDescriptor: descriptor,
                                launchIdentifiers: nil)
    }

    @objc func sharingItemSelected(_ sender: NSMenuItem) {
        guard let service = sender.representedObject as? NSSharingService else {
            assertionFailure("representedObject is not NSSharingService")
            return
        }
        guard let tabViewModel = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController
                .tabCollectionViewModel.selectedTabViewModel,
              let url = tabViewModel.tab.content.url
        else {
            return
        }

        service.subject = tabViewModel.title
        service.perform(withItems: [url])
    }

}

private extension NSMenuItem {

    convenience init(service: NSSharingService) {
        var isMailService = false
        if service.responds(to: NSSelectorFromString("name")),
           let name = service.value(forKey: "name") as? NSSharingService.Name,
           name == .composeEmail {
            isMailService = true
        }

        self.init(title: service.menuItemTitle, action: nil, keyEquivalent: isMailService ? "I" : "")
        if isMailService {
            self.keyEquivalentModifierMask = [.command, .shift]
        }
        self.image = service.image
        self.representedObject = service
    }

}

private extension NSImage {

    static var more: NSImage? {
        let sharedMoreMenuImageSelector = NSSelectorFromString("sharedMoreMenuImage")
        guard NSSharingServicePicker.responds(to: sharedMoreMenuImageSelector) else { return nil }
        return NSSharingServicePicker.perform(sharedMoreMenuImageSelector)?.takeUnretainedValue() as? NSImage
    }

}

private extension DescType {

    static let openSharingSubpane: DescType = 0x70747275

}
