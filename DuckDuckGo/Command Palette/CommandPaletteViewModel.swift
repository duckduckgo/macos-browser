//
//  CommandPaletteViewModel.swift
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
import CombineExt
import SwiftSoup

public enum Loadable<T> {
    case loading
    case loaded(T)
}
extension Loadable {
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    var value: T? {
        guard case let .loaded(some) = self else { return nil }
        return some
    }
}

final class CommandPaletteViewModel: CommandPaletteViewModelProtocol {

    @Published private var isLoading: Bool = false
    @Published private var suggestions = [CommandPaletteSection]()

    private var isLoadingAndSuggestions: (Bool, [CommandPaletteSection]) {
        get {
            (isLoading, suggestions)
        }
        set {
            dispatchPrecondition(condition: .onQueue(.main))
            (isLoading, suggestions) = newValue
        }
    }

    var suggestionsPublisher: AnyPublisher<[CommandPaletteSection], Never> {
        $suggestions.eraseToAnyPublisher()
    }
    var isLoadingPublisher: AnyPublisher<Bool, Never> {
        $isLoading.eraseToAnyPublisher()
    }
    var userInput: PassthroughSubject<String, Never> = .init()

    private var userInputCancellable: AnyCancellable?
    private var c: AnyCancellable?

    init() {
        userInputCancellable = userInput.debounce(for: .seconds(0.25), scheduler: RunLoop.main)
            .sink { [weak self] predicate in
                self?.userInputUpdated(predicate)
        }
    }

    typealias SectionPublisher = AnyPublisher<Loadable<[CommandPaletteSuggestion]>, Never>
    typealias PublishedSection = (section: CommandPaletteSection.Section, publisher: SectionPublisher)

    private let commands: [String: [CommandPaletteSection.Section]] = [
        "d": [.searchResults],
        "s": [.searchResults],
        "g": [.searchResults],

        "b": [.bookmarks],

        "c": [.currentWindowTabs],
        "o": [.otherWindowsTabs],

        "f": [.currentWindowTabs, .otherWindowsTabs],
        "t": [.currentWindowTabs, .otherWindowsTabs],

        "q": [.instantAnswers],
        "a": [.instantAnswers],

        "h": [.help],
        "help": [.help],

        "dev": [.inspector],
        "ins": [.inspector],
        "src": [.inspector],

        "gg": [.copyURL],
        "cp": [.copyURL],
    ]

    private let hiddenCommands: Set<CommandPaletteSection.Section> = [
        .help,
        .inspector,
        .copyURL
    ]

    private func publisher(for section: CommandPaletteSection.Section, matching predicate: String) -> SectionPublisher {
        switch section {
        case .help:
            return helpSection()
        case .currentWindowTabs:
            return activeWindowTabs(matching: predicate)
        case .otherWindowsTabs:
            return tabs(matching: predicate)
        case .bookmarks:
            return bookmarks(for: predicate)
        case .searchResults:
            return searchResults(for: predicate)
        case .instantAnswers:
            return instantAnswers(for: predicate)
        case .inspector:
            return inspector()
        case .copyURL:
            return copyPageAddress()
        }
    }

    private func userInputUpdated(_ predicate: String) {
        var predicate = predicate.trimmingWhitespaces()
        guard !predicate.isEmpty else {
            c = nil
            isLoadingAndSuggestions = (false, [])
            return
        }

        var filteredSections = CommandPaletteSection.Section.allCases.filter { !hiddenCommands.contains($0) }

        if predicate.hasPrefix(":") {
            let endIdx = predicate.firstIndex(of: " ") ?? predicate.endIndex
            let cmd = String(predicate[predicate.index(after: predicate.startIndex)..<endIdx])
            if !cmd.isEmpty, let sections = commands[cmd] {
                filteredSections = sections
                predicate = endIdx < predicate.endIndex ? String(predicate[endIdx...]).trimmingWhitespaces() : ""
            }
        }

        let publishers: [PublishedSection] = filteredSections.map {
            ($0, publisher(for: $0, matching: predicate))
        }

        c = publishers
            .map(\.publisher)
            .combineLatest()
            .map {
                (isLoading: $0.contains(where: { $0.isLoading }),
                 suggestions: $0.enumerated().compactMap {
                    ($0.element.value?.isEmpty == false)
                        ? CommandPaletteSection(section: publishers[$0.offset].section, suggestions: $0.element.value!)
                        : nil
                })
            }
            .weakAssign(to: \.isLoadingAndSuggestions, on: self)
    }
}

private extension CommandPaletteViewModel {
    
    func filterTabs(matching predicate: String) -> (MainWindowController) -> [CommandPaletteSuggestion] {
        { windowController in

            let model = windowController.mainViewController!.tabCollectionViewModel
            let isMainWindow = windowController.window!.isMainWindow

            return model.tabCollection.tabs.enumerated().filter {
                guard !isMainWindow || model.selectionIndex != $0.offset else { return false }

                let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

                return $0.element.title?.range(of: predicate, options: options, locale: .current) != nil
                    || $0.element.url?.absoluteString.range(of: predicate, options: options, locale: .current) != nil

            }.compactMap {

                model.tabViewModel(for: $0.element).map { tabViewModel in
                    (model: tabViewModel, activate: {
                        guard let idx = model.tabCollection.tabs.firstIndex(of: tabViewModel.tab) else { return }
                        model.select(at: idx)
                        if !windowController.window!.isMainWindow {
                            windowController.window!.makeKeyAndOrderFront(nil)
                        }
                    })
                 }

            }.map(CommandPaletteSuggestion.tab(model:activate:))

        }
    }

    func activeWindowTabs(matching predicate: String) -> SectionPublisher {
        let tabs: [CommandPaletteSuggestion]
        if let keyWindowController = WindowControllersManager.shared.lastKeyMainWindowController {
            tabs = filterTabs(matching: predicate)(keyWindowController)
        } else {
            tabs = []
        }

        return Just(tabs)
            .map(Loadable.loaded)
            .eraseToAnyPublisher()
    }

    func tabs(matching predicate: String) -> SectionPublisher {
        let keyWindowController = WindowControllersManager.shared.lastKeyMainWindowController
        let tabs = WindowControllersManager.shared.mainWindowControllers
            .filter { $0 !== keyWindowController }
            .map(filterTabs(matching: predicate))
            .reduce([], +)

        return Just(tabs)
            .map(Loadable.loaded)
            .eraseToAnyPublisher()
    }

    func helpSection() -> SectionPublisher {
        let model = SearchResult(title: "Show Commands Help",
                                 snippet: nil,
                                 url: nil,
                                 favicon: nil,
                                 faviconURL: URL(string: "https://external-content.duckduckgo.com/ip3/duckduckgo.com.ico")!)
        return Just(.loaded([CommandPaletteSuggestion.searchResult(model: model, activate: {
            WindowsManager.openNewWindow(with: Bundle.main.url(forResource: "command_help", withExtension: "html")!)
        })])).eraseToAnyPublisher()
    }

    func inspector() -> SectionPublisher {
        let model = SearchResult(title: "Show Page Inspector",
                                 snippet: nil,
                                 url: nil,
                                 favicon: nil,
                                 faviconURL: nil)
        return Just(.loaded([CommandPaletteSuggestion.searchResult(model: model, activate: {
            guard let inspector = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController?
                .tabCollectionViewModel
                .selectedTabViewModel?
                .tab
                .webView
                .value(forKey: "inspector") as? NSObject
            else { return }

            inspector.perform(Selector(("show")))
        })])).eraseToAnyPublisher()
    }

    func copyPageAddress() -> SectionPublisher {
        guard let url = WindowControllersManager.shared.lastKeyMainWindowController?.mainViewController?
            .tabCollectionViewModel
            .selectedTabViewModel?
            .tab
            .url
        else { return Just(.loaded([])).eraseToAnyPublisher() }

        let model = SearchResult(title: "Copy Page Address",
                                 snippet: nil,
                                 url: url,
                                 favicon: nil,
                                 faviconURL: nil)
        return Just(.loaded([CommandPaletteSuggestion.searchResult(model: model, activate: {

            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.URL], owner: nil)
            (url as NSURL).write(to: pasteboard)

        })])).eraseToAnyPublisher()
    }

    func searchResults(for query: String) -> SectionPublisher {
        SearchResultsProvider.shared.querySearchResults(for: query)
            .map {
                $0.first(5) + [
                    SearchResult(title: "More results from DuckDuckGo...",
                                 snippet: nil,
                                 url: .makeHTMLSearchURL(from: query)!,
                                 favicon: nil,
                                 faviconURL: URL(string: "https://external-content.duckduckgo.com/ip3/duckduckgo.com.ico")!)
                ]
            }
            .replaceError(with: [])
            .map {
                .loaded($0.map { model in
                    CommandPaletteSuggestion.searchResult(model: model, activate: {
                        WindowsManager.openNewWindow(with: model.url!)
                    })
                })
            }
            .multicast(subject: CurrentValueSubject(.loading))
            .autoconnect()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func instantAnswers(for query: String) -> SectionPublisher {
        InstantAnswersProvider.shared.queryInstantAnswers(for: query)
            .replaceError(with: [])
            .map {
                .loaded($0.map { model in
                    let title = (try? SwiftSoup.parse(model.result).select("a").first()?.text()) ?? ""
                    let snippet = model.text
                    let iconURL = model.icon.url.isEmpty ? nil : URL(string: model.icon.url, relativeTo: .duckDuckGoAPI)
                    let searchResult = SearchResult(title: title,
                                                    snippet: snippet,
                                                    url: model.url,
                                                    favicon: nil,
                                                    faviconURL: iconURL)
                    return CommandPaletteSuggestion.searchResult(model: searchResult, activate: {
                        WindowsManager.openNewWindow(with: model.url)
                    })
                }.first(5))
            }
            .multicast(subject: CurrentValueSubject(.loading))
            .autoconnect()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func bookmarks(for query: String) -> SectionPublisher {
        LocalBookmarkManager.shared.findBookmarks(with: query)
            .map {
                .loaded($0.map { bookmark in
                    let searchResult = SearchResult(title: bookmark.title,
                                                    snippet: nil,
                                                    url: bookmark.url,
                                                    favicon: bookmark.favicon,
                                                    faviconURL: nil)
                    return CommandPaletteSuggestion.searchResult(model: searchResult, activate: {
                        WindowsManager.openNewWindow(with: bookmark.url)
                    })
                })
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

}
