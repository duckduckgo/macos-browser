//
//  TemporaryFileHandler.swift
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

final class TemporaryFileHandler {
    
    enum FileHandlerError: Error {
        case noFileFound
        case failedToCopyFile
    }
    
    func copyFileToTemporaryDirectory(fileURL: URL, handler: @escaping (Result<URL, FileHandlerError>) -> Void) {
        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            handler(.failure(.noFileFound))
            return
        }
        
        let fileExtension = fileURL.pathExtension
        let newFileName = UUID().uuidString
        let finalTemporaryFileURL = temporaryDirectoryURL.appendingPathComponent(newFileName).appendingPathExtension(fileExtension)
        
        do {
            try fileManager.copyItem(at: fileURL, to: finalTemporaryFileURL)
        } catch {
            handler(.failure(.failedToCopyFile))
            return
        }
        
        // Pass the newly copied file URL to the handler.
        handler(.success(finalTemporaryFileURL))
        
        // With the handler complete, delete the file.
        do {
            try fileManager.removeItem(at: finalTemporaryFileURL)
        } catch {
            assertionFailure("Failed to remove temporarily copied file")
        }
    }
    
}
