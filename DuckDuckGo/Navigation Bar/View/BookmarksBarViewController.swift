//
//  BookmarksBarViewController.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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
import AppKit

final class BookmarksBarViewController: NSViewController {
 
    @IBOutlet var bookmarksCollectionView: NSCollectionView!
    
    let totalDataSourceCount: Int = 10
    var currentMaximumCells: Int = 10 {
        didSet {
            bookmarksCollectionView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(frameChanged), name: NSView.frameDidChangeNotification, object: self.view)

        let nib = NSNib(nibNamed: BookmarksBarCollectionViewItem.identifier.rawValue, bundle: nil)
        bookmarksCollectionView.register(nib, forItemWithIdentifier: BookmarksBarCollectionViewItem.identifier)
        bookmarksCollectionView.delegate = self
        bookmarksCollectionView.dataSource = self
        
        (bookmarksCollectionView.collectionViewLayout as? NSCollectionViewGridLayout)?.minimumInteritemSpacing = 10.0
        (bookmarksCollectionView.collectionViewLayout as? NSCollectionViewGridLayout)?.margins = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 10.0)
    }
    
    @objc
    private func frameChanged() {
        print("Frame changed \(self.bookmarksCollectionView.visibleItems().count)")
        
        calculateMaximumVisibleItems(viewWidth: view.bounds.width)
    }
    
    private func calculateMaximumVisibleItems(viewWidth: CGFloat) {
        let cellWidth = 100
        let spacing = 10
        let totalCellWidth = CGFloat(cellWidth + spacing)
        
        let maximumVisibleCells = floor(viewWidth / totalCellWidth)
        
        print(maximumVisibleCells)
        
        currentMaximumCells = Int(maximumVisibleCells)
    }
    
}

extension BookmarksBarViewController: NSCollectionViewDataSource {
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return min(currentMaximumCells, totalDataSourceCount)
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: BookmarksBarCollectionViewItem.identifier, for: indexPath)
        guard let firePopoverItem = item as? BookmarksBarCollectionViewItem else { return item }
        
        print("Made item at \(indexPath.item)")
        
        return firePopoverItem
    }
    
}

extension BookmarksBarViewController: NSCollectionViewDelegate {
    
}

extension BookmarksBarViewController: NSCollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        return NSSize(width: 100, height: 20)
    }
    
}
