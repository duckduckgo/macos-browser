//
//  TrackerRadarConfigurationUpdater.swift
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

import Combine
import os

struct TrackerRadarConfigurationUpdater: ConfiguationUpdating {

    let downloader: ConfigurationDownloader

    func update() -> AnyPublisher<Void, Error> {
        return Future { promise in

            var cancellable: AnyCancellable?

            cancellable = downloader.download(.trackerRadar, embeddedEtag: TrackerDataManager.Constants.embeddedDataSetETag)
                .mapError { error -> Error in
                    os_log("Failed to retrieve TrackerRadar data %s", type: .error, error.localizedDescription)
                    return error
                }
                .compactMap { $0 }
                .map { $0.etag }
                .sink { _ in

                    withExtendedLifetime(cancellable) { _ in }
                    promise(.success(()))
                    cancellable = nil

                } receiveValue: { value in

                    TrackerDataManager.shared.reload(etag: value)

                }

        }.eraseToAnyPublisher()
    }

}
