//
//  HistoryCoordinator.swift
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
import os.log
import Combine
import BrowserServicesKit

typealias History = [HistoryEntry]

protocol HistoryCoordinating: AnyObject {

    var history: History? { get }

    func addVisit(of url: URL)
    func updateTitleIfNeeded(title: String, url: URL)
    func markDownloadUrl(_ url: URL)
    func markFailedToLoadUrl(_ url: URL)

    func burnHistory(except fireproofDomains: FireproofDomains, completion: @escaping () -> Void)

}

/// Coordinates access to History. Uses its own queue with high qos for all operations.
final class HistoryCoordinator: HistoryCoordinating {

    static let shared = HistoryCoordinator()

    private init() {
        commonInit()
    }

    init(historyStoring: HistoryStoring) {
        self.historyStoring = historyStoring

        commonInit()
    }

    func commonInit() {
        cleanOldHistory()
        scheduleRegularCleaning()
    }

    private lazy var historyStoring: HistoryStoring = HistoryStore()
    private let queue = DispatchQueue(label: "history.coordinator.queue", qos: .userInitiated, attributes: .concurrent)
    private var regularCleaningTimer: Timer?

    // Source of truth
    private var historyDictionary: [URL: HistoryEntry]?

    // Output
    private var _history: History?
    var history: History? {
        queue.sync { self._history }
    }

    private var cancellables = Set<AnyCancellable>()

    func addVisit(of url: URL) {
        queue.async(flags: .barrier) { [weak self] in
            guard var historyDictionary = self?.historyDictionary else {
                os_log("Visit of %s ignored", log: .history, url.absoluteString)
                return
            }

            var entry = historyDictionary[url] ?? HistoryEntry(url: url)
            entry.addVisit()
            entry.failedToLoad = false

            historyDictionary[url] = entry
            self?.historyDictionary = historyDictionary
            self?._history = self?.makeHistory(from: historyDictionary)
            self?.save(entry: entry)

            self?.generateRootUrlIfNeeded(from: url)
        }
    }

    func updateTitleIfNeeded(title: String, url: URL) {
        queue.async(flags: .barrier) { [weak self] in
            guard var historyDictionary = self?.historyDictionary else { return }
            guard var entry = historyDictionary[url] else {
                os_log("Title update ignored - URL not part of history yet", type: .debug)
                return
            }
            guard !title.isEmpty, entry.title != title else { return }

            entry.title = title
            historyDictionary[url] = entry
            self?.historyDictionary = historyDictionary
            self?._history = self?.makeHistory(from: historyDictionary)
            self?.save(entry: entry)
        }
    }

    func markFailedToLoadUrl(_ url: URL) {
        mark(url: url, keyPath: \HistoryEntry.failedToLoad, value: true)
    }

    func markDownloadUrl(_ url: URL) {
        mark(url: url, keyPath: \HistoryEntry.isDownload, value: true)

        queue.async(flags: .barrier) { [weak self] in
            guard let historyDictionary = self?.historyDictionary else { return }
            if !url.isRoot, let rootUrl = url.root, let rootEntry = historyDictionary[rootUrl], rootEntry.numberOfVisits == 0 {
                self?.mark(url: rootUrl, keyPath: \HistoryEntry.isDownload, value: true)
            }
        }
    }

    func burnHistory(except fireproofDomains: FireproofDomains, completion: @escaping () -> Void) {
        queue.async(flags: .barrier) { [weak self] in
            guard let history = self?._history else { return }
            let exceptions: [HistoryEntry] = history.compactMap({ historyEntry in
                if fireproofDomains.isURLFireproof(url: historyEntry.url) {
                    return historyEntry
                }
                return nil
            })

            self?.cleanAndReloadHistory(until: .distantFuture, except: exceptions, completionHandler: { _ in
                DispatchQueue.main.async {
                    completion()
                }
            })
        }
    }

    @objc private func cleanOldHistory() {
        cleanAndReloadHistory(until: .monthAgo, except: [])
    }

    private func cleanAndReloadHistory(until date: Date,
                                       except exceptions: [HistoryEntry],
                                       completionHandler: ((Error?) -> Void)? = nil) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            self.cancellables = Set<AnyCancellable>()
            self.historyStoring.cleanAndReloadHistory(until: date, except: exceptions)
                .receive(on: self.queue, options: .init(flags: .barrier))
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        os_log("History cleaned and loaded successfully", log: .history)
                        completionHandler?(nil)
                    case .failure(let error):
                        os_log("Cleaning and loading of history failed: %s", log: .history, type: .error, error.localizedDescription)
                        completionHandler?(error)
                    }
                }, receiveValue: { [weak self] history in
                    self?.historyDictionary = self?.makeHistoryDictionary(from: history)
                    self?._history = history
                })
                .store(in: &self.cancellables)
        }
    }

    private func scheduleRegularCleaning() {
        let timer = Timer(fireAt: .startOfDayTomorrow,
                          interval: .day,
                          target: self,
                          selector: #selector(cleanOldHistory),
                          userInfo: nil,
                          repeats: true)
        RunLoop.main.add(timer, forMode: RunLoop.Mode.common)
        regularCleaningTimer = timer
    }

    private func makeHistoryDictionary(from history: History) -> [URL: HistoryEntry] {
        history.reduce(into: [URL: HistoryEntry](), { $0[$1.url] = $1 })
    }

    private func makeHistory(from dictionary: [URL: HistoryEntry]) -> History {
        return History(dictionary.values)
    }

    private func save(entry: HistoryEntry) {
        self.historyStoring.save(entry: entry)
            .receive(on: self.queue, options: .init(flags: .barrier))
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("Visit entry updated successfully. URL: %s, Title: %s, Number of visits: %d, failed to load: %s, is download: %s",
                           log: .history,
                           entry.url.absoluteString,
                           entry.title ?? "",
                           entry.numberOfVisits,
                           entry.failedToLoad ? "yes" : "no",
                           entry.isDownload ? "yes" : "no")
                case .failure(let error):
                    os_log("Saving of history entry failed: %s", log: .history, type: .error, error.localizedDescription)
                }
            }, receiveValue: {})
            .store(in: &self.cancellables)
    }

    /// For the better user experience
    /// When visiting a domain for the first time using a non-root URL, generating its root URL and adding into the history with the visit count 0
    /// triggers the autocompletion of the root URL.
    private func generateRootUrlIfNeeded(from url: URL) {
        queue.async(flags: .barrier) { [weak self] in
            guard var historyDictionary = self?.historyDictionary else {
                os_log("Root URL of %s not saved. History not loaded yet", log: .history, url.absoluteString)
                return
            }

            guard !url.isRoot, let rootUrl = url.root, historyDictionary[rootUrl] == nil else {
                return
            }

            let entry = HistoryEntry(url: rootUrl)

            historyDictionary[rootUrl] = entry
            self?.historyDictionary = historyDictionary
            self?._history = self?.makeHistory(from: historyDictionary)
            self?.save(entry: entry)
        }
    }

    /// Sets boolean value for the keyPath in HistroryEntry for the specified url
    /// Does the same for the root URL if it has no visits
    private func mark(url: URL, keyPath: WritableKeyPath<HistoryEntry, Bool>, value: Bool) {
        queue.async(flags: .barrier) { [weak self] in
            guard var historyDictionary = self?.historyDictionary, var entry = historyDictionary[url] else {
                os_log("Marking of %s not saved. History not loaded yet or entry doesn't exist",
                       log: .history, url.absoluteString)
                return
            }

            entry[keyPath: keyPath] = value

            historyDictionary[url] = entry
            self?.historyDictionary = historyDictionary
            self?._history = self?.makeHistory(from: historyDictionary)
            self?.save(entry: entry)
        }
    }

}
