//
//  HomePageSyncTabsModel.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import Combine
import Foundation
import SyncDataProviders

extension TabInfo: Identifiable {
    public var id: String {
        UUID().uuidString
    }
}

extension DeviceTabsInfo: Identifiable {
    public var id: String {
        deviceId
    }
}

extension HomePage.Models {

    final class SyncTabsModel: ObservableObject {

        @Published var deviceTabs: [DeviceTabsInfo] = []

        let open: (URL, FavoritesModel.OpenTarget) -> Void

        @MainActor
        init(open: @escaping (URL, FavoritesModel.OpenTarget) -> Void) {
            self.open = open
            syncDidUpdateTabsCancellable = NSApp.delegateTyped.syncDataProviders.tabsAdapter.syncDidCompletePublisher
                .sink { [weak self] _ in
                    self?.reloadDeviceTabs()
                }

            reloadDeviceTabs()
        }

        @MainActor
        func reloadDeviceTabs() {

            Task { @MainActor in
                let deviceTabs = (try? NSApp.delegateTyped.syncDataProviders.tabsAdapter.tabsStore?.getDeviceTabs()) ?? []
                print("loaded \(deviceTabs.count) device tabs")
                let devices = try await NSApp.delegateTyped.syncService?.fetchDevices()
                self.deviceTabs = deviceTabs
                    .filter { !$0.deviceTabs.isEmpty }
                    .map { object in
                        guard let deviceName = devices?.first(where: { $0.id == object.deviceId })?.name else {
                            return object
                        }
                        return DeviceTabsInfo(deviceId: deviceName, deviceTabs: object.deviceTabs)
                    }
            }
        }

        func openInNewTab(_ url: URL) {
            open(url, .newTab)
        }

        func openInNewWindow(_ url: URL) {
            open(url, .newWindow)
        }

        func open(_ url: URL) {
            open(url, .current)
        }

        private var syncDidUpdateTabsCancellable: AnyCancellable?
    }

}
