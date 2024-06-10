//
//  PrintPanelAccessoryView.swift
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
import SwiftUI

// TODO: Rename
struct PrintPanelAccessoryView: View {

    @StateObject var marginsModel: PrintingMarginsViewModel
    @StateObject var settingsModel: PrintSettingsViewModel

    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 0
        return formatter
    }()

    // TODO: DPI: 72
    // TODO: mm/inch/points switch
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Margins (inches)")
                .font(.headline)

            HStack {
                Text("Top:")
                Spacer()
                Stepper(value: $marginsModel.topMargin, step: 0.1) {
                    TextField("Top Margin", value: $marginsModel.topMargin, formatter: numberFormatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                }
            }

            HStack {
                Text("Bottom:")
                Spacer()
                Stepper(value: $marginsModel.bottomMargin, step: 0.1) {
                    TextField("Bottom Margin", value: $marginsModel.bottomMargin, formatter: numberFormatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                }
            }

            HStack {
                Text("Left:")
                Spacer()
                Stepper(value: $marginsModel.leftMargin, step: 0.1) {
                    TextField("Left Margin", value: $marginsModel.leftMargin, formatter: numberFormatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                }
            }

            HStack {
                Text("Right:")
                Spacer()
                Stepper(value: $marginsModel.rightMargin, step: 0.1) {
                    TextField("Right Margin", value: $marginsModel.rightMargin, formatter: numberFormatter)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                }
            }

            HStack {
                Toggle("Print headers and footers", isOn: $settingsModel.shouldPrintHeadersAndFooters)
            }
            HStack {
                Toggle("Print backgrounds", isOn: $settingsModel.shouldPrintBackgrounds)
            }
        }
        .padding()
    }
}

final class PrintPanelAccessoryViewController: NSViewController {

    @objc let marginsModel: PrintingMarginsViewModel
    @objc let settingsModel: PrintSettingsViewModel

    init(printInfo: NSPrintInfo) {
        self.marginsModel = PrintingMarginsViewModel(printInfo: printInfo)
        self.settingsModel = PrintSettingsViewModel(printInfo: printInfo)
        super.init(nibName: nil, bundle: nil)

        title = "Margins"
    }

    required init?(coder: NSCoder) {
        fatalError("\(Self.self): Bad initializer")
    }

    override func loadView() {
        let marginView = PrintPanelAccessoryView(marginsModel: self.marginsModel, settingsModel: self.settingsModel)
        view = NSHostingView(rootView: marginView)
    }

    override var preferredContentSize: NSSize {
        get {
            NSSize(width: 500, height: 500)
        }
        set {}
    }
}

extension PrintPanelAccessoryViewController: NSPrintPanelAccessorizing {

    func localizedSummaryItems() -> [[NSPrintPanel.AccessorySummaryKey: String]] {
        let summaryItems: [[NSPrintPanel.AccessorySummaryKey: String]] = [
            [.itemName: "Top Margin",
             .itemDescription: "\(marginsModel.topMargin) inches"],
            [.itemName: "Bottom Margin",
             .itemDescription: "\(marginsModel.bottomMargin) inches"],
            [.itemName: "Left Margin",
             .itemDescription: "\(marginsModel.leftMargin) inches"],
            [.itemName: "Right Margin",
             .itemDescription: "\(marginsModel.rightMargin) inches"],
            [.itemName: "Print Backgrounds",
             .itemDescription: "\(settingsModel.shouldPrintBackgrounds)"],
            [.itemName: "Print Headers and Footers",
             .itemDescription: "\(settingsModel.shouldPrintHeadersAndFooters)"],
        ]
        return summaryItems
    }

    func keyPathsForValuesAffectingPreview() -> Set<String> {
        return [
            #keyPath(marginsModel.topMargin),
            #keyPath(marginsModel.bottomMargin),
            #keyPath(marginsModel.leftMargin),
            #keyPath(marginsModel.rightMargin),
            #keyPath(settingsModel.shouldPrintBackgrounds),
            #keyPath(settingsModel.shouldPrintHeadersAndFooters),
        ]
    }

}

#if DEBUG
extension PrintPanelAccessoryViewController {
    convenience init() {
        self.init(printInfo: .shared)
    }
}
@available(macOS 14.0, *)
#Preview {
    PrintPanelAccessoryViewController()
}
#endif
