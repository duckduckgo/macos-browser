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

final class CommandPaletteViewModel: CommandPaletteViewModelProtocol {

    @Published private var suggestions = [CommandPaletteSection]()

    var suggestionsPublisher: AnyPublisher<[CommandPaletteSection], Never> {
        $suggestions.eraseToAnyPublisher()
    }
    var userInput: PassthroughSubject<String, Never> = .init()
    var userInputCancellable: AnyCancellable?

    init() {
        userInputCancellable = userInput.debounce(for: .seconds(0.25), scheduler: RunLoop.main)
            .sink { [weak self] predicate in
                self?.userInputUpdated(predicate)
        }
    }

    func userInputUpdated(_ predicate: String) {
        guard !predicate.isEmpty else {
            suggestions = []
            return
        }

        var suggestions = [CommandPaletteSection]()

        func filterTabs(of windowController: MainWindowController) -> [CommandPaletteSuggestion] {
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

        let keyWindowController = WindowControllersManager.shared.lastKeyMainWindowController
        if let keyWindowController = keyWindowController {
            let tabs = filterTabs(of: keyWindowController)
            if !tabs.isEmpty {
                suggestions.append(.init(title: "Current window", suggestions: tabs))
            }
        }

        let otherTabs = WindowControllersManager.shared.mainWindowControllers
            .filter { $0 !== keyWindowController }
            .map(filterTabs(of:))
            .reduce([], +)
        if !otherTabs.isEmpty {
            suggestions.append(.init(title: "Other windows", suggestions: otherTabs))
        }

        self.suggestions = suggestions
    }

}
