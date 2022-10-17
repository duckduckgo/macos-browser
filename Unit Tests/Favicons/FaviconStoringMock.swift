//
//  FaviconStoringMock.swift
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
import XCTest
import Combine
@testable import DuckDuckGo_Privacy_Browser

final class FaviconStoringMock: FaviconStoring {

    func loadFavicons() -> Future<[Favicon], Error> {
        return Future { promise in
            promise(.success([]))
        }
    }

    func save(favicon: Favicon) -> Future<Void, Error> {
        return Future { promise in
            promise(.success(()))
        }
    }

    func removeFavicons(_ favicons: [Favicon]) -> Future<Void, Error> {
        return Future { promise in
            promise(.success(()))
        }
    }

    func loadFaviconReferences() -> Future<([FaviconHostReference], [FaviconUrlReference]), Error> {
        return Future { promise in
            promise(.success(([],[])))
        }
    }

    func save(hostReference: FaviconHostReference) -> Future<Void, Error> {
        return Future { promise in
            promise(.success(()))
        }
    }

    func save(urlReference: FaviconUrlReference) -> Future<Void, Error> {
        return Future { promise in
            promise(.success(()))
        }
    }

    func remove(hostReferences: [FaviconHostReference]) -> Future<Void, Error> {
        return Future { promise in
            promise(.success(()))
        }
    }

    func remove(urlReferences: [FaviconUrlReference]) -> Future<Void, Error> {
        return Future { promise in
            promise(.success(()))
        }
    }

}
