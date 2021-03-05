//
//  TabsSearchService.swift
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
import GRDB

private enum TitleUpdatedOrNavigationEvent {
//    case titleUpdated(String?)
    case navigationEvent(NavigationEvent)
}
private typealias TabNavEventChange = Publishers.NestedObjectChanges<
    AnyPublisher<TitleUpdatedOrNavigationEvent, Never>,
    Published<[Tab]>.Publisher>.Change
private typealias WindowControllerTabLoadedChange = Publishers.NestedObjectChanges<
    AnyPublisher<TabNavEventChange, Never>,
    Published<[MainWindowController]>.Publisher>.Change

private extension Tab {
    var titleOrNavigationPublisher: AnyPublisher<TitleUpdatedOrNavigationEvent, Never> {
        navigationEvents.map(TitleUpdatedOrNavigationEvent.navigationEvent)
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
//            .merge(with: $title.map(TitleUpdatedOrNavigationEvent.titleUpdated))
            .eraseToAnyPublisher()
    }
}
private extension TabCollectionViewModel {
    var tabUpdated: AnyPublisher<TabNavEventChange, Never> {
        return tabCollection.$tabs.nestedObjectChanges(\.titleOrNavigationPublisher).eraseToAnyPublisher()
    }
}
private extension WindowControllersManager {
    var pageLoadedPublisher: AnyPublisher<WindowControllerTabLoadedChange, Never> {
        $mainWindowControllers.nestedObjectChanges(\.mainViewController!.tabCollectionViewModel.tabUpdated)
            .eraseToAnyPublisher()
    }
}

struct FullTextTabSearchResult {
    let controller: MainWindowController
    let tabViewModel: TabViewModel
    let snippet: NSAttributedString?
}

final class TabsSearchService {
    static let shared = TabsSearchService()

    private let db: DatabaseQueue
    private let dbQueue = DispatchQueue(label: "TabsSearchService.dbQueue")
    private var tabViewModels = [TabId: (windowController: MainWindowController, viewModel: TabViewModel)]()

    private var c: AnyCancellable?

    init() {
        do {
            db = try DatabaseQueue(path: ":memory:")
            try db.write { db in
                try db.execute(sql: """
                    CREATE VIRTUAL TABLE bodies USING FTS5(text, id, tokenize="porter unicode61");
                """)
            }
        } catch {
            fatalError("\(error)")
        }

        c = WindowControllersManager.shared.pageLoadedPublisher.sink { [weak self] in
            guard let self = self else { return }
            switch $0 {
            case .composition(added: let added, removed: let removed):
                added.forEach(self.added(controller:))
                removed.forEach(self.removed(controller:))

            case .value(owner: let controller, value: let value):
                switch value {
                case .composition(added: let added, removed: let removed):
                    self.added(added, in: controller)
                    self.removed(removed)

//                case .value(owner: let tab, value: .titleUpdated(let title)):
//                    self.tab(tab, didUpdateTitle: title)
                case .value(owner: let tab, value: .navigationEvent(.pageFinishedLoading)):
                    self.tabDidFinishLoading(tab)

                case .value(owner: _, value: .navigationEvent):
                    break
                }
            }
        }

    }

    func added(controller: MainWindowController) {
        let tabs = controller.mainViewController!.tabCollectionViewModel.tabCollection.tabs
        self.added(Set(tabs), in: controller)
    }

    func added(_ tabs: Set<Tab>, in controller: MainWindowController) {
        let tabCollectionViewModel = controller.mainViewController!.tabCollectionViewModel
        for tab in tabs {
            self.tabViewModels[tab.id] = (controller, tabCollectionViewModel.tabViewModel(for: tab)!)
        }
        dbQueue.async { [db] in
            do {
                try db.write { db in
                    for tab in tabs {
//                        try db.execute(sql: "INSERT INTO titles(id, text) VALUES (?, ?)", arguments: [tab.id.rawValue, tab.title])
                        try db.execute(sql: "INSERT INTO bodies(id, text) VALUES (?, NULL)", arguments: [tab.id.rawValue])
                    }
                }
            } catch {
                print(error)
            }
        }
    }

    func removed(controller: MainWindowController) {
        let tabs = controller.mainViewController!.tabCollectionViewModel.tabCollection.tabs
        self.removed(Set(tabs))
    }

    func removed(_ tabs: Set<Tab>) {
        for tab in tabs {
            self.tabViewModels[tab.id] = nil
        }
        dbQueue.async { [db] in
            do {
                try db.write { db in
                    for tab in tabs {
//                        try db.execute(sql: "DELETE FROM titles WHERE id=?", arguments: [tab.id.rawValue])
                        try db.execute(sql: "DELETE FROM bodies WHERE id=?", arguments: [tab.id.rawValue])
                    }
                }
            } catch {
                print(error)
            }
        }
    }

//    func tab(_ tab: Tab, didUpdateTitle title: String?) {
//        dbQueue.async { [db] in
//            do {
//                try db.write { db in
//                    try db.execute(sql: "UPDATE titles SET text=? WHERE id=?", arguments: [title, tab.id.rawValue])
//                }
//            } catch {
//                print(error)
//            }
//        }
//    }

    func tabDidFinishLoading(_ tab: Tab) {
        tab.webView.evaluateJavaScript("document.body.innerText") { [db, dbQueue] result, error in
            dbQueue.async {
                guard let text = result as? String? else { return }
                do {
                    try db.write { db in
                        try db.execute(sql: "UPDATE bodies SET text=? WHERE id=?", arguments: [text, tab.id.rawValue])
                    }
                } catch {
                    print(error)
                }
            }
        }
    }

    func search(_ query: String) -> Future<[FullTextTabSearchResult], Error> {
        return Future { [db, dbQueue, tabViewModels] promise in
            dbQueue.async {
                do {
                    let results = try db.read { db -> [FullTextTabSearchResult] in
                        var results = [FullTextTabSearchResult]()
//                        let titleQuery = "%" + query/*.map(String.init).joined(separator: "%")*/ + "%"
                        let bodyQuery = query.replacingOccurrences(of: "*", with: "") + "*"

                        let rows = try Row.fetchCursor(db, sql: """
                            SELECT id, snippet(bodies, 0, '<b>', '</b>', '', 3) AS spt
                                FROM bodies WHERE text MATCH ? ORDER BY rank;
                        """, arguments: [bodyQuery])

                        while let row = try rows.next() {
                            let id: Int = row["id"]
                            guard let model = tabViewModels[TabId(rawValue: id)] else { continue }

                            let snippet: String = row["spt"]
                            let textAttributes: [NSAttributedString.Key: Any] = [
                                .font: NSFont.systemFont(ofSize: 13, weight: .bold),
                                .foregroundColor: NSColor.textColor
                            ]

                            var resultSnippet = NSMutableAttributedString()
                            if let attrSnippet = NSAttributedString(html: snippet.data(using: .utf8)!,
                                                                    options: [:],
                                                                    documentAttributes: nil) {
                                let str = attrSnippet.string as NSString
                                attrSnippet.enumerateAttributes(in: NSRange(location: 0, length: str.length), options: []) { (attrs, range, _) in
                                    let substr = str.substring(with: range)
                                    if let font = attrs[.font] as? NSFont,
                                       font.fontName.contains("Bold") {

                                        resultSnippet.append(NSAttributedString(string: substr, attributes: textAttributes))
                                    } else {
                                        resultSnippet.append(NSAttributedString(string: substr))
                                    }
                                }
                            } else {
                                resultSnippet = NSMutableAttributedString(string: snippet)
                            }
                            results.append( FullTextTabSearchResult(controller: model.windowController,
                                                                    tabViewModel: model.viewModel,
                                                                    snippet: resultSnippet) )
                        }
                        return results
                    }
                    promise(.success(results))
                } catch {
                    promise(.failure(error))
                }
            }
        }
    }

}
