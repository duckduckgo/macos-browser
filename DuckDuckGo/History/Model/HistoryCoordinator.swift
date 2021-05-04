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

protocol HistoryCoordinating: AnyObject {

    var history: History? { get }

    func addVisit(of url: URL)
    func updateTitleIfNeeded(title: String, url: URL)
    func burnHistory(except fireproofedDomains: [String])

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
        cleanAndReloadHistory()
        scheduleRegularCleaning()
    }

    private lazy var historyStoring: HistoryStoring = HistoryStore()
    private let queue = DispatchQueue(label: "history.coordinator.queue", qos: .userInitiated, attributes: .concurrent)
    private var regularCleaningTimer: Timer?

    private var _history: History?
    // TODO: get rid of dictionary - it's useless? - make set lookup more effective
    private var historyDictionary: [URL: HistoryEntry]?

    private var cancellables = Set<AnyCancellable>()

    var history: History? {
        queue.sync { self._history }
    }

    func addVisit(of url: URL) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            guard self.historyDictionary != nil else {
                os_log("Visit of %s ignored. On main thread: %s", log: .history, url.absoluteString, Thread.isMainThread ? "yes" : "no")
                return
            }

            var entry: HistoryEntry
            if let existingEntry = self.historyDictionary?[url] {
                entry = existingEntry
                entry.addVisit()
            } else {
                entry = HistoryEntry(url: url)
            }
            self.historyDictionary?[url] = entry
            self.save(entry: entry)
        }
    }

    func updateTitleIfNeeded(title: String, url: URL) {
        queue.async(flags: .barrier) { [weak self] in
            guard var historyDictionary = self?.historyDictionary else { return }
            guard var entry = historyDictionary[url] else {
                assertionFailure("URL not part of history yet")
                return
            }
            guard !title.isEmpty, entry.title != title else { return }

            entry.title = title
            historyDictionary[url] = entry
            self?._history = self?.makeHistory(from: historyDictionary)
            self?.historyDictionary = historyDictionary
            self?.save(entry: entry)
        }
    }

    func burnHistory(except fireproofedDomains: [String]) {
        queue.async(flags: .barrier) { [weak self] in
            // TODO burn except domainsp
        }
    }

    @objc private func cleanAndReloadHistory() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            self.cancellables = Set<AnyCancellable>()
            self.historyStoring.cleanAndReloadHistory(since: .weekAgo)
                .receive(on: self.queue)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        os_log("History cleaned and loaded successfully. On main thread: %s", log: .history, Thread.isMainThread ? "yes" : "no")
                    case .failure(let error):
                        os_log("Cleaning and loading of history failed: %s", log: .history, type: .error, error.localizedDescription)
                    }
                }, receiveValue: { [weak self] history in
                    self?._history = history
                    self?.historyDictionary = self?.makeHistoryDictionary(from: history)
                })
                .store(in: &self.cancellables)
        }
    }

    private func makeHistoryDictionary(from history: History) -> [URL: HistoryEntry] {
        history.reduce(into: [URL: HistoryEntry](), { $0[$1.url] = $1 })
    }

    private func scheduleRegularCleaning() {
        let timer = Timer(fireAt: .midnight,
                          interval: .day,
                          target: self,
                          selector: #selector(cleanAndReloadHistory),
                          userInfo: nil,
                          repeats: true)
        RunLoop.main.add(timer, forMode: RunLoop.Mode.common)
        regularCleaningTimer = timer
    }

    private func makeHistory(from dictionary: [URL: HistoryEntry]) -> History {
        return History(dictionary.values)
    }

    private func save(entry: HistoryEntry) {
        self.historyStoring.save(entry: entry)
            .receive(on: self.queue)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    os_log("Visit entry updated successfully. URL: %s, Title: %s, Number of visits: %d, On main thread: %s",
                           log: .history,
                           entry.url.absoluteString,
                           entry.title ?? "",
                           entry.numberOfVisits,
                           Thread.isMainThread ? "yes" : "no")
                case .failure(let error):
                    os_log("Saving of history entry failed: %s", log: .history, type: .error, error.localizedDescription)
                }
            }, receiveValue: {})
            .store(in: &self.cancellables)
    }

}

fileprivate extension TimeInterval {

    static var day: TimeInterval = 60 * 60 * 24 * 7

}

fileprivate extension Date {

    static var weekAgo: Date {
        Date().addingTimeInterval( -1 * TimeInterval.day )
    }

    static var midnight: Date {
        return Calendar.current.date(
            bySettingHour: 23,
            minute: 59,
            second: 0,
            of: Date())!
    }

}
