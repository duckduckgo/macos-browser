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

    override init(title: String) {
        super.init(title: title)

        self.autoenablesItems = true
        self.delegate = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func update() {
        let services = .copyLink + .urlSharingServices + .qrCode

        guard services != items.compactMap({ $0.representedObject as? NSSharingService }) else { return }

        self.items = services.map { service in
            NSMenuItem(service: service, target: self, action: #selector(sharingItemSelected))
        } + [
            NSMenuItem(title: UserText.moreMenuItem, action: #selector(openSharingPreferences), target: self).withImage(.sharedMoreMenu)
        ]
    }

    typealias SharingData = (title: String?, items: [Any])
    @MainActor
    private func sharingData() -> SharingData? {
        guard let tabViewModel = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController.tabCollectionViewModel.selectedTabViewModel,
              tabViewModel.canReload,
              !tabViewModel.isShowingErrorPage,
              let url = tabViewModel.tab.content.userEditableUrl else { return nil }

        let sharingData = DuckPlayer.shared.sharingData(for: tabViewModel.title, url: url) ?? (tabViewModel.title, url)

        return (sharingData.title, [url])
    }

    @objc func openSharingPreferences(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *),
           let preferencesLink = URL(string: "x-apple.systempreferences:com.apple.preferences.extensions?Sharing") {

            NSWorkspace.shared.open(preferencesLink)
            return
        }

        let url = URL(fileURLWithPath: "/System/Library/PreferencePanes/Extensions.prefPane")
        let plist = [
            "action": "revealExtensionPoint",
            "protocol": "com.apple.share-services"
        ]
        let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let descriptor = NSAppleEventDescriptor(descriptorType: .openSharingSubpane, data: data)

        // the non-deprecated method with NSWorkspace.OpenConfiguration doesn‘t work for Sharing Preferences
        (NSWorkspace.shared as Workspace).open([url],
                                               withAppBundleIdentifier: nil,
                                               options: [],
                                               additionalEventParamDescriptor: descriptor,
                                               launchIdentifiers: nil)
    }

    @MainActor
    @objc func sharingItemSelected(_ sender: NSMenuItem) {
        guard let service = sender.representedObject as? NSSharingService else {
            assertionFailure("representedObject is not NSSharingService")
            return
        }
        guard let sharingData = self.sharingData(), !sharingData.items.isEmpty else { return }

        if service == .copyLink {
            NSPasteboard.general.copy(sharingData.items)
            return
        }

        service.subject = sharingData.title
        service.perform(withItems: sharingData.items.filter { service.canPerform(withItems: [$0]) })
    }

}

extension SharingMenu: NSMenuItemValidation {

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(sharingItemSelected):
            guard let sharingData = self.sharingData(),
                  let service = menuItem.representedObject as? NSSharingService else { return false }

            if service == .copyLink {
                return true
            }

            return sharingData.items.contains(where: { service.canPerform(withItems: [$0]) })

        case #selector(openSharingPreferences):
            return true

        default:
            return true
        }
    }

}

extension SharingMenu: NSMenuDelegate {

    func menuHasKeyEquivalent(_ menu: NSMenu, for event: NSEvent, target: AutoreleasingUnsafeMutablePointer<AnyObject?>, action: UnsafeMutablePointer<Selector?>) -> Bool {
        if self.numberOfItems == 0 {
            self.update()
        }
        return false
    }

}

private extension NSPasteboard {

    func copy(_ sharedItems: [Any]) {
        let url = sharedItems.first(where: { $0 is URL }) as? URL
        let string = sharedItems.first(where: { $0 is String }) as? String
        if let url {
            self.copy(url, withString: string)
        } else if let string {
            self.copy(string)
        } else {
            assertionFailure("Cannot copy items \(sharedItems)")
        }
    }

}

private extension NSMenuItem {

    convenience init(service: NSSharingService, target: AnyObject, action: Selector) {
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
        self.target = target
        self.action = action
    }

}

private extension NSImage {

    static var sharedMoreMenu: NSImage? {
        let sharedMoreMenuImageSelector = NSSelectorFromString("sharedMoreMenuImage")
        guard NSSharingServicePicker.responds(to: sharedMoreMenuImageSelector) else { return nil }
        return NSSharingServicePicker.perform(sharedMoreMenuImageSelector)?.takeUnretainedValue() as? NSImage
    }

}

private extension DescType {

    static let openSharingSubpane: DescType = 0x70747275

}

private extension NSSharingService {

    static let copyLink = NSSharingService(named: .copyLink)
    static let addToSafariReadingList = NSSharingService(named: .addToSafariReadingList)

}

private extension [NSSharingService] {

    static let copyLink = NSSharingService(named: .copyLink).map { [$0] } ?? []
    static let qrCode = [NSSharingService.qrCode]

    static var urlSharingServices: [NSSharingService] {
        // not real sharing URL, used for generating items for NSURL and NSString
        NSSharingService.sharingServices(forItems: [URL.duckDuckGo]).filter {
            $0 != NSSharingService.addToSafariReadingList
        }
    }

}

private extension NSSharingService.Name {
    static let copyLink = NSSharingService.Name("com.apple.CloudSharingUI.CopyLink")
}
