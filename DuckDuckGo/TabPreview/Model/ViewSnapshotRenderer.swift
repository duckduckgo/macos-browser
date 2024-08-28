//
//  ViewSnapshotRenderer.swift
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

import Foundation
import Common
import WebKit
import os.log

protocol ViewSnapshotRendering {

    @MainActor
    func renderSnapshot(view: NSView) async -> NSImage?

}

final class ViewSnapshotRenderer: ViewSnapshotRendering {

    func renderSnapshot(view: NSView) async -> NSImage? {
        await withCheckedContinuation { continuation in
            renderSnapshot(view: view) { image in
                continuation.resume(returning: image)
            }
        }
    }

    func renderSnapshot(view: NSView, completion: @escaping (NSImage?) -> Void) {
        let originalBounds = view.bounds

        Logger.tabSnapshots.debug("Native snapshot rendering started")
        DispatchQueue.global(qos: .userInitiated).async {
            guard let resizedImage = self.createResizedImage(from: view, with: originalBounds) else {
                DispatchQueue.main.async {
                    Logger.tabSnapshots.error("Native snapshot rendering failed")
                    completion(nil)
                }
                return
            }

            DispatchQueue.main.async {
                completion(resizedImage)

                Logger.tabSnapshots.debug("Snapshot of native page rendered")
            }
        }
    }

    private func createResizedImage(from view: NSView, with bounds: CGRect) -> NSImage? {
        let originalSize = bounds.size
        let targetWidth = CGFloat(TabPreviewWindowController.width)
        let targetHeight = originalSize.height * (targetWidth / originalSize.width)

        guard let bitmapRep = createBitmapRepresentation(size: originalSize) else { return nil }
        renderView(view, to: bitmapRep, size: originalSize)

        let originalImage = NSImage(size: originalSize)
        originalImage.addRepresentation(bitmapRep)

        let resizedImage = originalImage.resized(to: NSSize(width: targetWidth, height: targetHeight))
        return resizedImage
    }

    private func createBitmapRepresentation(size: CGSize) -> NSBitmapImageRep? {
        NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: NSColorSpaceName.deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0)
    }

    private func renderView(_ view: NSView, to bitmapRep: NSBitmapImageRep, size: CGSize) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }

        if let context = NSGraphicsContext(bitmapImageRep: bitmapRep) {
            NSGraphicsContext.current = context
            DispatchQueue.main.sync {
                assert(Thread.isMainThread)
                context.cgContext.translateBy(x: 0, y: size.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                view.layer?.render(in: context.cgContext)
            }
        }
    }

}
