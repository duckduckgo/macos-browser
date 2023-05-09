//
//  DownloadListViewModel.swift
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

import Foundation
import Combine

@MainActor
final class DownloadListViewModel {

    private let coordinator: DownloadListCoordinator
    private var viewModels: [UUID: DownloadViewModel]
    private var cancellable: AnyCancellable?

    @Published private(set) var items: [DownloadViewModel]

    init(coordinator: DownloadListCoordinator = DownloadListCoordinator.shared) {
        self.coordinator = coordinator

        let items = coordinator.downloads(sortedBy: \.added, ascending: false).map(DownloadViewModel.init)
        self.items = items
        self.viewModels = items.reduce(into: [:]) { $0[$1.id] = $1 }
        cancellable = coordinator.updates.receive(on: DispatchQueue.main).sink { [weak self] update in
            self?.handleDownloadsUpdate(of: update.kind, item: update.item)
        }
    }

    private func handleDownloadsUpdate(of kind: DownloadListCoordinator.UpdateKind, item: DownloadListItem) {
        dispatchPrecondition(condition: .onQueue(.main))
        switch kind {
        case .added:
            let viewModel = DownloadViewModel(item: item)
            self.viewModels[item.identifier] = viewModel
            self.items.insert(viewModel, at: 0)
        case .updated:
            self.viewModels[item.identifier]?.update(with: item)
        case .removed:
            guard let index = self.items.firstIndex(where: { $0.id == item.identifier }) else {
                return
            }
            self.viewModels[item.identifier] = nil
            self.items.remove(at: index)
        }
    }

    func cleanupInactiveDownloads() {
        coordinator.cleanupInactiveDownloads()
    }

    func filterRemovedDownloads() {
        items = items.filter {
            if let localUrl = $0.localURL {
                let fileSize = try? localUrl.resourceValues(forKeys: [.fileSizeKey]).fileSize
                return fileSize != nil || $0.isActive
            } else {
                return true
            }
        }
    }

    func cancelDownload(at index: Int) {
        guard let item = items[safe: index] else {
            assertionFailure("DownloadListViewModel: no item at \(index)")
            return
        }
        coordinator.cancel(downloadWithIdentifier: item.id)
    }

    func removeDownload(at index: Int) {
        guard let item = items[safe: index] else {
            assertionFailure("DownloadListViewModel: no item at \(index)")
            return
        }
        coordinator.remove(downloadWithIdentifier: item.id)
    }

    func restartDownload(at index: Int) {
        guard let item = items[safe: index] else {
            assertionFailure("DownloadListViewModel: no item at \(index)")
            return
        }
        coordinator.restart(downloadWithIdentifier: item.id)
    }

}
