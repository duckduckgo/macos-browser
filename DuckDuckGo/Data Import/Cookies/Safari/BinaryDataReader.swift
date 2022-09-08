//
//  BinaryDataReader.swift
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

final class BinaryDataReader {
    private(set) var data: Data
    private(set) var cursor: Int = 0

    init(data: Data) {
        self.data = data
    }

    func readSlice(length: Int) -> Data {
        let slice = self.slice(loc: cursor, len: length)
        cursor += length
        return slice
    }

    func readIntLE() -> UInt32 {
        let value = readIntLE(at: cursor)
        cursor += 4
        return value
    }

    func readIntBE() -> UInt32 {
        let value = readIntBE(at: cursor)
        cursor += 4
        return value
    }

    func readDoubleLE() -> Double {
        let value = readDoubleLE(at: cursor)
        cursor += 8
        return value
    }

    func readIntLE(at offset: Int) -> UInt32 {
        let data = slice(loc: offset, len: 4)
        let out: UInt32 = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        return out
    }

    func readIntBE(at offset: Int) -> UInt32 {
        readIntLE(at: offset).byteSwapped
    }

    func readDoubleLE(at offset: Int) -> Double {
        let data = slice(loc: offset, len: 8)
        let out: Double = data.withUnsafeBytes { $0.load(as: Double.self) }
        return out
    }

    func slice(loc: Int, len: Int) -> Data {
        data.subdata(in: loc..<loc+len)
    }
}
