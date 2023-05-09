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
import Combine
import Common
import BrowserServicesKit

typealias History = [HistoryEntry]

protocol HistoryCoordinating: AnyObject {

    var history: History? { get }
    var historyDictionaryPublisher: Published<[URL: HistoryEntry]?>.Publisher { get }

    func addVisit(of url: URL)
    func addBlockedTracker(entityName: String, on url: URL)
    func trackerFound(on: URL)
    func updateTitleIfNeeded(title: String, url: URL)
    func markFailedToLoadUrl(_ url: URL)
    func commitChanges(url: URL)

    func title(for url: URL) -> String?

    func burn(except fireproofDomains: FireproofDomains, completion: @escaping () -> Void)
    func burnDomains(_ domains: Set<String>, completion: @escaping () -> Void)
    func burnVisits(_ visits: [Visit], completion: @escaping () -> Void)

}

/// Coordinates access to History. Uses its own queue with high qos for all operations.
final class HistoryCoordinator: HistoryCoordinating {

    static let shared = HistoryCoordinator()

    private init() {}

    init(historyStoring: HistoryStoring) {
        self.historyStoring = historyStoring
        historyDictionary = [:]
    }

    func loadHistory() {
        cleanOldAndLoad { [weak self] _ in
            self?.migrateModelV5toV6IfNeeded()
        }
        scheduleRegularCleaning()
    }

    private lazy var historyStoring: HistoryStoring = HistoryStore()
    private var regularCleaningTimer: Timer?

    // Source of truth
    @Published private(set) var historyDictionary: [URL: HistoryEntry]?
    var historyDictionaryPublisher: Published<[URL: HistoryEntry]?>.Publisher { $historyDictionary }

    // Output
    var history: History? {
        guard let historyDictionary = historyDictionary else {
            return nil
        }

        return makeHistory(from: historyDictionary)
    }

    private var cancellables = Set<AnyCancellable>()

    func addVisit(of url: URL) {
        guard let historyDictionary = historyDictionary else {
            os_log("Visit of %s ignored", log: .history, url.absoluteString)
            return
        }

        let entry = historyDictionary[url] ?? HistoryEntry(url: url)
        entry.addVisit()
        entry.failedToLoad = false

        self.historyDictionary?[url] = entry
    }

    func addBlockedTracker(entityName: String, on url: URL) {
        guard let historyDictionary = historyDictionary else {
            os_log("Add tracker to %s ignored, no history", log: .history, url.absoluteString)
            return
        }

        guard let entry = historyDictionary[url] else {
            os_log("Add tracker to %s ignored, no entry", log: .history, url.absoluteString)
            return
        }

        entry.addBlockedTracker(entityName: entityName)
    }

    func trackerFound(on url: URL) {
        guard let historyDictionary = historyDictionary else {
            os_log("Add tracker to %s ignored, no history", log: .history, url.absoluteString)
            return
        }

        guard let entry = historyDictionary[url] else {
            os_log("Add tracker to %s ignored, no entry", log: .history, url.absoluteString)
            return
        }

        entry.trackersFound = true
    }

    func updateTitleIfNeeded(title: String, url: URL) {
        guard let historyDictionary = historyDictionary else { return }
        guard let entry = historyDictionary[url] else {
            os_log("Title update ignored - URL not part of history yet", log: .history, type: .debug)
            return
        }
        guard !title.isEmpty, entry.title != title else { return }

        entry.title = title
    }

    func markFailedToLoadUrl(_ url: URL) {
        mark(url: url, keyPath: \HistoryEntry.failedToLoad, value: true)
    }

    func commitChanges(url: URL) {
        guard let historyDictionary = historyDictionary,
              let entry = historyDictionary[url] else {
            return
        }

        save(entry: entry)
    }

    func title(for url: URL) -> String? {
        guard let historyEntry = historyDictionary?[url] else {
            return nil
        }

        return historyEntry.title
    }

    func burn(except fireproofDomains: FireproofDomains, completion: @escaping () -> Void) {
        guard let historyDictionary = historyDictionary else { return }

        let entries: [HistoryEntry] = historyDictionary.values.filter { historyEntry in
            return !fireproofDomains.isURLFireproof(url: historyEntry.url)
        }

        removeEntries(entries, completionHandler: { _ in
            completion()
        })
    }

    func burnDomains(_ domains: Set<String>, completion: @escaping () -> Void) {
        guard let historyDictionary = historyDictionary else { return }

        let entries: [HistoryEntry] = historyDictionary.values.filter { historyEntry in
            guard let host = historyEntry.url.host else {
                return false
            }

            return domains.contains(host)
        }

        removeEntries(entries, completionHandler: { _ in
            completion()
        })
    }

    func burnVisits(_ visits: [Visit], completion: @escaping () -> Void) {
        removeVisits(visits) { _ in
            completion()
        }
    }

    var cleaningDate: Date { .monthAgo }

    @objc private func cleanOld() {
        clean(until: cleaningDate)
    }

    private func cleanOldAndLoad(completionHandler: ((Error?) -> Void)?) {
        clean(until: cleaningDate, completionHandler: completionHandler)
    }

    private func clean(until date: Date,
                       completionHandler: ((Error?) -> Void)? = nil) {
        historyStoring.cleanOld(until: date)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("History cleaned successfully", log: .history)
                    completionHandler?(nil)
                case .failure(let error):
                    os_log("Cleaning of history failed: %s", log: .history, type: .error, error.localizedDescription)
                    completionHandler?(error)
                }
            }, receiveValue: { [weak self] history in
                self?.historyDictionary = self?.makeHistoryDictionary(from: history)
            })
            .store(in: &cancellables)
    }

    private func removeEntries(_ entries: [HistoryEntry],
                               completionHandler: ((Error?) -> Void)? = nil) {
        // Remove from the local memory
        entries.forEach { entry in
            historyDictionary?.removeValue(forKey: entry.url)
        }

        // Remove from the storage
        historyStoring.removeEntries(entries)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("Entries removed successfully", log: .history)
                    completionHandler?(nil)
                case .failure(let error):
                    assertionFailure("Removal failed")
                    os_log("Removal failed: %s", log: .history, type: .error, error.localizedDescription)
                    completionHandler?(error)
                }
            }, receiveValue: {})
            .store(in: &cancellables)
    }

    private func removeVisits(_ visits: [Visit],
                              completionHandler: ((Error?) -> Void)? = nil) {
        var entriesToRemove = [HistoryEntry]()

        // Remove from the local memory
        visits.forEach { visit in
            if let historyEntry = visit.historyEntry {
                historyEntry.visits.remove(visit)

                if historyEntry.visits.count > 0 {
                    if let newLastVisit = historyEntry.visits.map({ $0.date }).max() {
                        historyEntry.lastVisit = newLastVisit
                        save(entry: historyEntry)
                    } else {
                        assertionFailure("No history entry")
                    }
                } else {
                    entriesToRemove.append(historyEntry)
                }
            } else {
                assertionFailure("No history entry")
            }
        }

        // Remove from the storage
        historyStoring.removeVisits(visits)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                switch completion {
                case .finished:
                    os_log("Visits removed successfully", log: .history)
                    // Remove entries with no remaining visits
                    self?.removeEntries(entriesToRemove, completionHandler: completionHandler)
                case .failure(let error):
                    assertionFailure("Removal failed")
                    os_log("Removal failed: %s", log: .history, type: .error, error.localizedDescription)
                    completionHandler?(error)
                }
            }, receiveValue: {})
            .store(in: &cancellables)
    }

    private func scheduleRegularCleaning() {
        let timer = Timer(fireAt: .startOfDayTomorrow,
                          interval: .day,
                          target: self,
                          selector: #selector(cleanOld),
                          userInfo: nil,
                          repeats: true)
        RunLoop.main.add(timer, forMode: RunLoop.Mode.common)
        regularCleaningTimer = timer
    }

    private func makeHistoryDictionary(from history: History) -> [URL: HistoryEntry] {
        dispatchPrecondition(condition: .onQueue(.main))

        return history.reduce(into: [URL: HistoryEntry](), { $0[$1.url] = $1 })
    }

    private func makeHistory(from dictionary: [URL: HistoryEntry]) -> History {
        dispatchPrecondition(condition: .onQueue(.main))

        return History(dictionary.values)
    }

    private func save(entry: HistoryEntry) {
        guard let entryCopy = entry.copy() as? HistoryEntry else {
            assertionFailure("Copying HistoryEntry failed")
            return
        }
        entry.visits.forEach { $0.savingState = .saved }

        historyStoring.save(entry: entryCopy)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("Visit entry updated successfully. URL: %s, Title: %s, Number of visits: %d, failed to load: %s",
                           log: .history,
                           entry.url.absoluteString,
                           entry.title ?? "",
                           entry.numberOfTotalVisits,
                           entry.failedToLoad ? "yes" : "no")
                case .failure(let error):
                    os_log("Saving of history entry failed: %s", log: .history, type: .error, error.localizedDescription)
                }
            }, receiveValue: {})
            .store(in: &cancellables)
    }

    /// Sets boolean value for the keyPath in HistroryEntry for the specified url
    /// Does the same for the root URL if it has no visits
    private func mark(url: URL, keyPath: WritableKeyPath<HistoryEntry, Bool>, value: Bool) {
        guard let historyDictionary = historyDictionary, var entry = historyDictionary[url] else {
            os_log("Marking of %s not saved. History not loaded yet or entry doesn't exist",
                   log: .history, url.absoluteString)
            return
        }

        entry[keyPath: keyPath] = value
    }

    // V5 to V6 custom migration

    @UserDefaultsWrapper(key: .historyV5toV6Migration, defaultValue: false)
    private var historyV5toV6Migration: Bool

    private func migrateModelV5toV6IfNeeded() {
        guard let historyDictionary = historyDictionary,
              !historyV5toV6Migration else {
            return
        }

        historyV5toV6Migration = true

        for entry in historyDictionary.values where entry.visits.isEmpty {
            entry.addOldVisit(date: entry.lastVisit)
            save(entry: entry)
        }
    }

}
