//
//  FileDownloadError.swift
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

import Foundation

enum FileDownloadError: Error {
    case failedToMoveFileToDownloads
    case failedToCompleteDownloadTask(underlyingError: Error?, resumeData: Data?, isRetryable: Bool)

    var isNSFileReadUnknownError: Bool {
        switch self {
        case .failedToMoveFileToDownloads:
            return false
        case .failedToCompleteDownloadTask(let underlyingError, _, _):
            guard let underlyingError else { return false }

            let nsError = underlyingError as NSError
            return nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadUnknownError
        }
    }
}

extension FileDownloadError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .failedToMoveFileToDownloads:
            return "FileDownloadError: failedToMoveFileToDownloads"
        case .failedToCompleteDownloadTask(underlyingError: let error, resumeData: let data, isRetryable: let isRetryable):
            return "FileDownloadError(\(isRetryable ? "retryable\(data != nil ? "+resumeData" : "")" : "non-retryable")) underlyingError: \(error.debugDescription)"
        }
    }
}

extension FileDownloadError {

    var underlyingError: Error? {
        guard case .failedToCompleteDownloadTask(underlyingError: let error, resumeData: _, isRetryable: _) = self else { return nil }
        return error
    }

    var isCancelled: Bool {
        (underlyingError as? URLError)?.code == URLError.cancelled
    }

    var resumeData: Data? {
        guard case .failedToCompleteDownloadTask(underlyingError: _, resumeData: let data, isRetryable: _) = self else { return nil }
        return data
    }

    var isRetryable: Bool {
        guard case .failedToCompleteDownloadTask(underlyingError: _, resumeData: _, isRetryable: let isRetryable) = self else { return false }
        return isRetryable
    }

}

extension FileDownloadError: CustomNSError {

    static var errorDomain: String { "FileDownloadError" }

    private enum ErrorCode: Int {
        case failedToMoveFileToDownloads = 0
        case failedToCompleteDownloadTask = 1
    }

    var errorCode: Int {
        switch self {
        case .failedToMoveFileToDownloads: return ErrorCode.failedToMoveFileToDownloads.rawValue
        case .failedToCompleteDownloadTask: return ErrorCode.failedToCompleteDownloadTask.rawValue
        }
    }

    private enum UserInfoKeys: String {
        case underlyingError
        case resumeData
        case isRetryable
    }

    var errorUserInfo: [String: Any] {
        switch self {
        case .failedToMoveFileToDownloads: return [:]
        case .failedToCompleteDownloadTask(underlyingError: let error, resumeData: let data, isRetryable: let isRetryable):
            var userInfo = [String: Any]()
            userInfo[UserInfoKeys.underlyingError.rawValue] = error
            userInfo[UserInfoKeys.resumeData.rawValue] = data
            userInfo[UserInfoKeys.isRetryable.rawValue] = NSNumber(value: isRetryable)
            return userInfo
        }
    }

    init(_ error: NSError) {
        var isRetryable: Bool {
            (error.userInfo[UserInfoKeys.isRetryable.rawValue] as? NSNumber)?.boolValue ?? false
        }
        switch ErrorCode(rawValue: error.domain == Self.errorDomain ? error.code : -1) {
        case .failedToMoveFileToDownloads:
            self = .failedToMoveFileToDownloads
        case .failedToCompleteDownloadTask:
            let underlyingError = error.userInfo[UserInfoKeys.underlyingError.rawValue] as? Error
            let data = error.userInfo[UserInfoKeys.resumeData.rawValue] as? Data
            self = .failedToCompleteDownloadTask(underlyingError: underlyingError, resumeData: data, isRetryable: isRetryable)
        default:
            self = .failedToCompleteDownloadTask(underlyingError: error, resumeData: nil, isRetryable: isRetryable)
        }
    }

}

extension FileDownloadError: Equatable {

    static func == (lhs: FileDownloadError, rhs: FileDownloadError) -> Bool {
        switch lhs {
        case .failedToMoveFileToDownloads: if case .failedToMoveFileToDownloads = rhs { return true }
        case .failedToCompleteDownloadTask(underlyingError: let error1, resumeData: let data1, isRetryable: let isRetryable):
            if case .failedToCompleteDownloadTask(underlyingError: let error2, resumeData: let data2, isRetryable: isRetryable) = rhs {
                return type(of: error1) == type(of: error2) && data1?.count == data2?.count
            }
        }
        return false
    }

}
