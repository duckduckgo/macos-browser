//
//  DataBrokerProtectionScheduler.swift
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

import Foundation

class DataBrokerProtectionScheduler {
    let activity: NSBackgroundActivityScheduler
    lazy var dataBrokerProcessor: DataBrokerProtectionProcessor = {

        DataBrokerProtectionProcessor(database:DataBrokerProtectionDataBase() ,
                                                      config: DataBrokerProtectionSchedulerConfig(),
                                                      operationRunnerProvider: DataBrokerOperationRunnerProvider())
    }()

      init() {
          let identifier = "com.dbp.duckduckgo"
          activity = NSBackgroundActivityScheduler(identifier: identifier)
          activity.repeats = true

          // Scheduling an activity to fire between 15 and 45 minutes from now
          activity.interval = 30 * 60
          activity.tolerance = 15 * 60

          activity.qualityOfService = QualityOfService.utility
      }

    public func start() {
        activity.schedule { completion in
            print("Running databroker processor...")
            self.dataBrokerProcessor.runQueuedOperations {
                completion(.finished)
            }
        }
    }

    public func stop() {
        activity.invalidate()
    }

    public func scanAllBrokers() {
        self.dataBrokerProcessor.runScanOnAllDataBrokers()
    }
}
