//
//  SyncSetupView.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
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

import SwiftUI
import SwiftUIExtensions

struct SyncSetupView<ViewModel>: View where ViewModel: ManagementViewModel {
    @EnvironmentObject var model: ViewModel

    var body: some View {
        PreferencePaneSection {
            VStack(alignment: .leading, spacing: 12) {
                Text(UserText.syncSetupExplanation)
                    .fixMultilineScrollableText()
                Spacer()
                Group {
                    if model.isCreatingAccount {
                        if #available(macOS 11.0, *) {
                            ProgressView()
                        } else {
                            EmptyView()
                        }
                    } else {
                        HStack(spacing: 24.0) {
                            let iconFrameSize = 24.0
                            let iconSize = NSSize(width: 64, height: 48)
                            let saveIcon = {
                                Image(nsImage: NSImage(named: "Default-App-128")!.resized(to: iconSize)!)
                                    .frame(width: iconFrameSize, height: iconFrameSize)
                            }
                            let syncIcon = {
                                Image(nsImage: NSImage(named: "Default-App-128")!.resized(to: iconSize)!)
                                    .frame(width: iconFrameSize, height: iconFrameSize)
                            }
                            CardTemplate(title: UserText.startNewBackupCardTitle, summary: UserText.startNewBackupCardDesctiption, actionText: UserText.startNewBackupCardAction, icon: saveIcon, width: 240, height: 160) {
                                model.turnOnSync()
                            }
                            CardTemplate(title: UserText.syncAnotherDeviceCardTitle, summary: UserText.syncAnotherDeviceCardDesctiption, actionText: UserText.syncAnotherDeviceCardAction, icon: syncIcon, width: 240, height: 160) {
                                model.presentSyncAnotherDeviceDialog()
                            }
                        }
                    }
                }.frame(minWidth: 100)
            }
        }

//        PreferencePaneSection {
//            HStack {
//                Spacer()
//                Image("SyncSetup")
//                Spacer()
//            }
//        }
    }
}

extension NSImage {

    func resized(to size: NSSize) -> NSImage? {
        let image = NSImage(size: size)
        let targetRect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        let currentRect = NSRect(x: 0, y: 0, width: self.size.width, height: self.size.height)

        image.lockFocus()
        let graphicsContext = NSGraphicsContext.current
        graphicsContext?.imageInterpolation = .high
        self.draw(in: targetRect, from: currentRect, operation: .copy, fraction: 1)
        image.unlockFocus()

        return image
    }
}
