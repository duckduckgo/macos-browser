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
    case failedToCompleteDownloadTask(underlyingError: Error?, resumeData: Data?)
}

extension FileDownloadError {

    var underlyingError: Error? {
        guard case .failedToCompleteDownloadTask(underlyingError: let error, resumeData: _) = self else { return nil }
        return error
    }

    var isCancelled: Bool {
        (underlyingError as? URLError)?.code == URLError.cancelled
    }

    var resumeData: Data? {
        guard case .failedToCompleteDownloadTask(underlyingError: _, resumeData: let data) = self else { return nil }
        return data
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
    }

    var errorUserInfo: [String: Any] {
        switch self {
        case .failedToMoveFileToDownloads: return [:]
        case .failedToCompleteDownloadTask(underlyingError: let error, resumeData: let data):
            var userInfo = [String: Any]()
            userInfo[UserInfoKeys.underlyingError.rawValue] = error
            userInfo[UserInfoKeys.resumeData.rawValue] = data
            return userInfo
        }
    }

    init(_ error: NSError) {
        switch ErrorCode(rawValue: error.domain == Self.errorDomain ? error.code : -1) {
        case .failedToMoveFileToDownloads:
            self = .failedToMoveFileToDownloads
        case .failedToCompleteDownloadTask:
            let underlyingError = error.userInfo[UserInfoKeys.underlyingError.rawValue] as? Error
            let data = error.userInfo[UserInfoKeys.resumeData.rawValue] as? Data
            self = .failedToCompleteDownloadTask(underlyingError: underlyingError, resumeData: data)
        default:
            self = .failedToCompleteDownloadTask(underlyingError: error, resumeData: nil)
        }
    }

}

extension FileDownloadError: Equatable {

    static func == (lhs: FileDownloadError, rhs: FileDownloadError) -> Bool {
        switch lhs {
        case .failedToMoveFileToDownloads: if case .failedToMoveFileToDownloads = rhs { return true }
        case .failedToCompleteDownloadTask(underlyingError: let error1, resumeData: let data1):
            if case .failedToCompleteDownloadTask(underlyingError: let error2, resumeData: let data2) = rhs {
                return type(of: error1) == type(of: error2) && data1?.count == data2?.count
            }
        }
        return false
    }

}
