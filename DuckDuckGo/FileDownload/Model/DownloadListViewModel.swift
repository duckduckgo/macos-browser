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

import Combine
import Common
import Foundation
import os.log

@MainActor
final class DownloadListViewModel {

    private let fireWindowSession: FireWindowSessionRef?
    private let coordinator: DownloadListCoordinator
    private var viewModels: [UUID: DownloadViewModel]
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var items: [DownloadViewModel]
    @Published private(set) var shouldShowErrorBanner: Bool = false

    init(fireWindowSession: FireWindowSessionRef?, coordinator: DownloadListCoordinator = DownloadListCoordinator.shared) {
        self.fireWindowSession = fireWindowSession
        self.coordinator = coordinator

        let items = coordinator.downloads(sortedBy: \.added, ascending: false)
            .filter { $0.fireWindowSession == fireWindowSession }
            .map(DownloadViewModel.init)
        self.items = items
        self.viewModels = items.reduce(into: [:]) { $0[$1.id] = $1 }
        coordinator.updates.receive(on: DispatchQueue.main).sink { [weak self] update in
            self?.handleDownloadsUpdate(of: update.kind, item: update.item)
        }.store(in: &cancellables)
        self.setupErrorBannerBinding()
    }

    private func handleDownloadsUpdate(of kind: DownloadListCoordinator.UpdateKind, item: DownloadListItem) {
        Logger.fileDownload.debug("DownloadListViewModel: .\(String(describing: kind)) \(item.identifier)")

        dispatchPrecondition(condition: .onQueue(.main))
        switch kind {
        case .added:
            guard item.fireWindowSession == self.fireWindowSession else { return }

            let viewModel = DownloadViewModel(item: item)
            self.viewModels[item.identifier] = viewModel
            self.items.insert(viewModel, at: 0)
        case .updated:
            self.viewModels[item.identifier]?.update(with: item)
        case .removed:
            guard let index = self.items.firstIndex(where: { $0.id == item.identifier }) else { return }
            self.viewModels[item.identifier] = nil
            self.items.remove(at: index)
        }
    }

    private func setupErrorBannerBinding() {
        $items.flatMap { items in
                Publishers.MergeMany(items.map { $0.$state })
            }.map { state in
                if case .failed(let error) = state {
                    if error.isNSFileReadUnknownError && self.isAffectedMacOSVersion() {
                        return true
                    }
                }

                return false
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showError in
                self?.shouldShowErrorBanner = showError
            }
            .store(in: &cancellables)
    }

    /// macOS 15.0.x and 14.7.x have a bug that affects downloads. Apple fixed the issue on macOS 15.1
    /// For more information: https://app.asana.com/0/1204006570077678/1208522448255790/f
    private func isAffectedMacOSVersion() -> Bool {
        let currentVersion = AppVersion.shared.osVersion

        return currentVersion.hasPrefix("15.0") || currentVersion.hasPrefix("14.7.")
    }

    func cleanupInactiveDownloads() {
        coordinator.cleanupInactiveDownloads(for: fireWindowSession)
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
