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

    private func userInputUpdated(_ predicate: String) {
        guard !predicate.isEmpty else {
            c = nil
            isLoadingAndSuggestions = (false, [])
            return
        }

        let publishers: [PublishedSection] = [
            (.currentWindowTabs, activeWindowTabs(matching: predicate)),
            (.otherWindowsTabs, tabs(matching: predicate)),
            (.searchResults, searchResults(for: predicate)),
        ]

        c = publishers.enumerated()
            .map(\.element.publisher)
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

    private func filterTabs(matching predicate: String) -> (MainWindowController) -> [CommandPaletteSuggestion] {
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

    func searchResults(for query: String) -> SectionPublisher {
        SearchResultsProvider().querySearchResults(for: query)
            .map {
                $0 + [SearchResult(title: "More results from DuckDuckGo...",
                                   snippet: nil,
                                   url: .makeHTMLSearchURL(from: query)!,
                                   faviconURL: URL(string: "https://external-content.duckduckgo.com/ip3/duckduckgo.com.ico")!)]
            }
            .replaceError(with: [])
            .map {
                .loaded($0.map { model in
                    CommandPaletteSuggestion.searchResult(model: model, activate: {
                        WindowsManager.openNewWindow(with: model.url)
                    })
                })
            }
            .multicast(subject: CurrentValueSubject(.loading))
            .autoconnect()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

}
