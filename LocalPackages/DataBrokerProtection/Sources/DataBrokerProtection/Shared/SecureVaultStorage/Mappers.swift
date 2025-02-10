//
//  Mappers.swift
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

struct MapperToDB {

    private let mechanism: (Data) throws -> Data
    private let jsonEncoder = JSONEncoder()

    init(mechanism: @escaping (Data) throws -> Data) {
        self.mechanism = mechanism
        jsonEncoder.dateEncodingStrategy = .millisecondsSince1970
    }

    func mapToDB(id: Int64? = nil, profile: DataBrokerProtectionProfile) throws -> ProfileDB {
        .init(id: id, birthYear: try withUnsafeBytes(of: profile.birthYear) { try mechanism(Data($0)) })
    }

    func mapToDB(_ name: DataBrokerProtectionProfile.Name, relatedTo profileId: Int64) throws -> NameDB {
        .init(
            first: try mechanism(name.firstName.encoded),
            last: try mechanism(name.lastName.encoded),
            profileId: profileId,
            middle: try name.middleName.encoded(mechanism),
            suffix: try name.suffix.encoded(mechanism)
        )
    }

    func mapToDB(_ address: DataBrokerProtectionProfile.Address, relatedTo profileId: Int64) throws -> AddressDB {
        .init(
            city: try mechanism(address.city.encoded),
            state: try mechanism(address.state.encoded),
            profileId: profileId,
            street: try address.street.encoded(mechanism),
            zipCode: try address.zipCode.encoded(mechanism)
        )
    }

    func mapToDB(_ phone: String, relatedTo profileId: Int64) throws -> PhoneDB {
        .init(phoneNumber: try mechanism(phone.encoded), profileId: profileId)
    }

    func mapToDB(_ broker: DataBroker, id: Int64? = nil) throws -> BrokerDB {
        let encodedBroker = try jsonEncoder.encode(broker)
        return .init(id: id, name: broker.name, json: encodedBroker, version: broker.version, url: broker.url)
    }

    func mapToDB(_ profileQuery: ProfileQuery, relatedTo profileId: Int64) throws -> ProfileQueryDB {
        .init(
            id: profileQuery.id,
            profileId: profileId,
            first: try mechanism(profileQuery.firstName.encoded),
            last: try mechanism(profileQuery.lastName.encoded),
            middle: try profileQuery.middleName.encoded(mechanism),
            suffix: try profileQuery.suffix.encoded(mechanism),
            city: try mechanism(profileQuery.city.encoded),
            state: try mechanism(profileQuery.state.encoded),
            street: try profileQuery.street.encoded(mechanism),
            zipCode: try profileQuery.zip.encoded(mechanism),
            phone: try profileQuery.phone.encoded(mechanism),
            birthYear: try withUnsafeBytes(of: profileQuery.birthYear) { try mechanism(Data($0)) },
            deprecated: profileQuery.deprecated
        )
    }

    func mapToDB(_ extractedProfile: ExtractedProfile, brokerId: Int64, profileQueryId: Int64) throws -> ExtractedProfileDB {
        let encodedProfile = try jsonEncoder.encode(extractedProfile)

        return .init(
            id: nil,
            brokerId: brokerId,
            profileQueryId: profileQueryId,
            profile: try mechanism(encodedProfile),
            removedDate: nil // Removed data is initialized as empty when created.
        )
    }

    func mapToDB(_ historyEvent: HistoryEvent, brokerId: Int64, profileQueryId: Int64) throws -> ScanHistoryEventDB {
        let encodedEventType = try jsonEncoder.encode(historyEvent.type)

        return .init(
            brokerId: brokerId,
            profileQueryId: profileQueryId,
            event: encodedEventType,
            timestamp: historyEvent.date
        )
    }

    func mapToDB(_ historyEvent: HistoryEvent, brokerId: Int64, profileQueryId: Int64, extractedProfileId: Int64) throws -> OptOutHistoryEventDB {
        let encodedEventType = try jsonEncoder.encode(historyEvent.type)
        return .init(
            brokerId: brokerId,
            profileQueryId: profileQueryId,
            extractedProfileId: extractedProfileId,
            event: encodedEventType,
            timestamp: historyEvent.date
        )
    }

    func mapToDB(extractedProfileId: Int64, attemptUUID: UUID, dataBroker: String, lastStageDate: Date, startTime: Date) -> OptOutAttemptDB {
        .init(extractedProfileId: extractedProfileId,
              dataBroker: dataBroker,
              attemptId: attemptUUID.uuidString,
              lastStageDate: lastStageDate,
              startDate: startTime)
    }
}

struct MapperToModel {

    private let mechanism: (Data) throws -> Data
    private let jsonDecoder = JSONDecoder()

    init(mechanism: @escaping (Data) throws -> Data) {
        self.mechanism = mechanism
        self.jsonDecoder.dateDecodingStrategy = .millisecondsSince1970
    }

    func mapToModel(_ profile: FullProfileDB) throws -> DataBrokerProtectionProfile {
        .init(
            names: try profile.names.map(mapToModel(_:)),
            addresses: try profile.addresses.map(mapToModel(_:)),
            phones: try profile.phones.map(mapToModel(_:)),
            birthYear: try mechanism(profile.profile.birthYear).withUnsafeBytes {
                $0.load(as: Int.self)
            }
        )
    }

    private func mapToModel(_ nameDB: NameDB) throws -> DataBrokerProtectionProfile.Name {
        .init(
            firstName: try mechanism(nameDB.first).decoded,
            lastName: try mechanism(nameDB.last).decoded,
            middleName: try nameDB.middle.decode(mechanism),
            suffix: try nameDB.suffix.decode(mechanism)
        )
    }

    private func mapToModel(_ addressDB: AddressDB) throws -> DataBrokerProtectionProfile.Address {
        .init(
            city: try mechanism(addressDB.city).decoded,
            state: try mechanism(addressDB.state).decoded,
            street: try addressDB.street.decode(mechanism),
            zipCode: try addressDB.zipCode.decode(mechanism)
        )
    }

    private func mapToModel(_ phoneDB: PhoneDB) throws -> String {
        try mechanism(phoneDB.phoneNumber).decoded
    }

    func mapToModel(_ brokerDB: BrokerDB) throws -> DataBroker {
        let decodedBroker = try jsonDecoder.decode(DataBroker.self, from: brokerDB.json)

        return DataBroker(
            id: brokerDB.id,
            name: decodedBroker.name,
            url: decodedBroker.url,
            steps: decodedBroker.steps,
            version: decodedBroker.version,
            schedulingConfig: decodedBroker.schedulingConfig,
            parent: decodedBroker.parent,
            mirrorSites: decodedBroker.mirrorSites,
            optOutUrl: decodedBroker.optOutUrl
        )
    }

    func mapToModel(_ profileQueryDB: ProfileQueryDB) throws -> ProfileQuery {
        .init(
            id: profileQueryDB.id,
            firstName: try mechanism(profileQueryDB.first).decoded,
            lastName: try mechanism(profileQueryDB.last).decoded,
            middleName: try profileQueryDB.middle.decode(mechanism),
            suffix: try profileQueryDB.suffix.decode(mechanism),
            city: try mechanism(profileQueryDB.city).decoded,
            state: try mechanism(profileQueryDB.state).decoded,
            street: try profileQueryDB.street.decode(mechanism),
            zipCode: try profileQueryDB.zipCode.decode(mechanism),
            phone: try profileQueryDB.phone.decode(mechanism),
            birthYear: try mechanism(profileQueryDB.birthYear).withUnsafeBytes {
                $0.load(as: Int.self)
            },
            deprecated: profileQueryDB.deprecated
        )
    }

    func mapToModel(_ scanDB: ScanDB, events: [ScanHistoryEventDB]) throws -> ScanJobData {
        .init(
            brokerId: scanDB.brokerId,
            profileQueryId: scanDB.profileQueryId,
            preferredRunDate: scanDB.preferredRunDate,
            historyEvents: try events.map(mapToModel(_:)),
            lastRunDate: scanDB.lastRunDate
        )
    }

    func mapToModel(_ optOutDB: OptOutDB, extractedProfileDB: ExtractedProfileDB, events: [OptOutHistoryEventDB]) throws -> OptOutJobData {
        .init(
            brokerId: optOutDB.brokerId,
            profileQueryId: optOutDB.profileQueryId,
            createdDate: optOutDB.createdDate,
            preferredRunDate: optOutDB.preferredRunDate,
            historyEvents: try events.map(mapToModel(_:)),
            lastRunDate: optOutDB.lastRunDate,
            attemptCount: optOutDB.attemptCount,
            submittedSuccessfullyDate: optOutDB.submittedSuccessfullyDate,
            extractedProfile: try mapToModel(extractedProfileDB),
            sevenDaysConfirmationPixelFired: optOutDB.sevenDaysConfirmationPixelFired,
            fourteenDaysConfirmationPixelFired: optOutDB.fourteenDaysConfirmationPixelFired,
            twentyOneDaysConfirmationPixelFired: optOutDB.twentyOneDaysConfirmationPixelFired
        )
    }

    func mapToModel(_ extractedProfileDB: ExtractedProfileDB) throws -> ExtractedProfile {
        let extractedProfile = try jsonDecoder.decode(ExtractedProfile.self, from: try mechanism(extractedProfileDB.profile))
        return .init(id: extractedProfileDB.id,
                     name: extractedProfile.name,
                     alternativeNames: extractedProfile.alternativeNames,
                     addressFull: extractedProfile.addressFull,
                     addresses: extractedProfile.addresses,
                     phoneNumbers: extractedProfile.phoneNumbers,
                     relatives: extractedProfile.relatives,
                     profileUrl: extractedProfile.profileUrl,
                     reportId: extractedProfile.reportId,
                     age: extractedProfile.age,
                     email: extractedProfile.email,
                     removedDate: extractedProfileDB.removedDate,
                     identifier: extractedProfile.identifier)
    }

    func mapToModel(_ scanEvent: ScanHistoryEventDB) throws -> HistoryEvent {
        let decodedEventType = try jsonDecoder.decode(HistoryEvent.EventType.self, from: scanEvent.event)
        return .init(brokerId: scanEvent.brokerId, profileQueryId: scanEvent.profileQueryId, type: decodedEventType, date: scanEvent.timestamp)
    }

    func mapToModel(_ optOutEvent: OptOutHistoryEventDB) throws -> HistoryEvent {
        let decodedEventType = try jsonDecoder.decode(HistoryEvent.EventType.self, from: optOutEvent.event)
        return .init(
            extractedProfileId: optOutEvent.extractedProfileId,
            brokerId: optOutEvent.brokerId,
            profileQueryId: optOutEvent.profileQueryId,
            type: decodedEventType,
            date: optOutEvent.timestamp
        )
    }

    func mapToModel(_ optOutAttempt: OptOutAttemptDB) -> AttemptInformation {
        .init(extractedProfileId: optOutAttempt.extractedProfileId,
              dataBroker: optOutAttempt.dataBroker,
              attemptId: optOutAttempt.attemptId,
              lastStageDate: optOutAttempt.lastStageDate,
              startDate: optOutAttempt.startDate)
    }
}

extension Optional where Wrapped == String {

    func encoded(_ mechanism: (Data) throws -> Data) throws -> Data? {
        guard let value = self else {
            return nil
        }

        return try mechanism(value.encoded)
    }
}

extension String {

    var encoded: Data {
        guard let encodedString = self.data(using: .utf8) else {
            fatalError("Mappers: Failed trying to encode String")
        }

        return encodedString
    }
}

extension Optional where Wrapped == Data {

    func decode(_ mechanism: (Data) throws -> Data) throws -> String? {
        guard let value = self else {
            return nil
        }

        return try mechanism(value).decoded
    }
}

extension Data {

    var decoded: String {
        guard let decodedString = String(data: self, encoding: .utf8) else {
            fatalError("Mappers: Failed trying to decode data")
        }

        return decodedString
    }
}
