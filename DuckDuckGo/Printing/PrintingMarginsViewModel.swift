//
//  PrintingMarginsViewModel.swift
//
//  Copyright © 2024 DuckDuckGo. All rights reserved.
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
import Foundation

final class PrintingMarginsViewModel: NSObject, ObservableObject {

    private weak var printInfo: NSPrintInfo?

    private var isEditingMargins = false
    private var cancellables: Set<AnyCancellable>?

    private enum Constants {
        static let dpi: CGFloat = 72
    }

    @objc var topMargin: CGFloat {
        get {
            printInfo?.topMargin ?? 0
        }
        set {
            setMarginValue(newValue, at: \.topMargin)
        }
    }

    @objc var bottomMargin: CGFloat {
        get {
            printInfo?.bottomMargin ?? 0
        }
        set {
            setMarginValue(newValue, at: \.bottomMargin)
        }
    }

    @objc var leftMargin: CGFloat {
        get {
            printInfo?.leftMargin ?? 0
        }
        set {
            setMarginValue(newValue, at: \.leftMargin)
        }
    }

    @objc var rightMargin: CGFloat {
        get {
            printInfo?.rightMargin ?? 0
        }
        set {
            setMarginValue(newValue, at: \.rightMargin)
        }
    }

    init(printInfo: NSPrintInfo) {
        self.printInfo = printInfo
        super.init()

        cancellables = [
            preventWebKitChangingMargin(at: \.leftMargin, printInfo: printInfo),
            preventWebKitChangingMargin(at: \.rightMargin, printInfo: printInfo),
            preventWebKitChangingMargin(at: \.topMargin, printInfo: printInfo),
            preventWebKitChangingMargin(at: \.bottomMargin, printInfo: printInfo),
        ]
    }

    private func setMarginValue(_ newValue: CGFloat, at keyPath: ReferenceWritableKeyPath<NSPrintInfo, CGFloat>) {
        guard let printInfo, printInfo[keyPath: keyPath] != newValue,
              printInfo.validMarginRange(for: keyPath).contains(newValue) else { return }

        isEditingMargins = true
        defer { isEditingMargins = false }

        objectWillChange.send()

        willChangeValue(forKey: keyPath._kvcKeyPathString!)
        defer { didChangeValue(forKey: keyPath._kvcKeyPathString!) }

        printInfo[keyPath: keyPath] = newValue
        NSPrintInfo.shared[keyPath: keyPath] = newValue
        print(printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin,
              printInfo.paperSize.height - printInfo.topMargin - printInfo.bottomMargin)
    }

    private func preventWebKitChangingMargin(at keyPath: ReferenceWritableKeyPath<NSPrintInfo, CGFloat>, printInfo: NSPrintInfo) -> AnyCancellable {
        printInfo.publisher(for: keyPath)
            .scan((old: 0, new: 0), { (old: $0.new, new: $1) })
            .dropFirst()
            .sink { [weak self, weak printInfo] change in
                guard let self, let printInfo,
                      // PrintInfo margin value being changed by WebKit
                      !self.isEditingMargins,
                      change.old != change.new else { return }

                isEditingMargins = true
                defer { isEditingMargins = false }
                // rollback to the value set by us
                printInfo[keyPath: keyPath] = change.old
            }
    }

}
