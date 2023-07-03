// SPDX-License-Identifier: MIT
// Copyright © 2018-2021 WireGuard LLC. All Rights Reserved.

import Foundation
import Network

public extension IPv4Address {

    init?(addrInfo: addrinfo) {
        guard addrInfo.ai_family == AF_INET else { return nil }

        let inAddr = addrInfo.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
        self.init(in_addr: inAddr)
    }

    // swiftlint:disable:next identifier_name
    init?(in_addr: Darwin.in_addr) {
        let addressData = withUnsafePointer(to: in_addr) { ptr in
            Data(bytes: ptr, count: MemoryLayout.size(ofValue: in_addr))
        }

        self.init(addressData)
    }

    // swiftlint:disable:next identifier_name
    var in_addr: Darwin.in_addr {
        self.rawValue.withUnsafeBytes {
            $0.bindMemory(to: Darwin.in_addr.self).baseAddress!.pointee
        }
    }

    var sockaddr: Darwin.sockaddr {
        var addr = Darwin.sockaddr()
        withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { ptr in
                ptr.pointee.sin_family = sa_family_t(AF_INET)
                ptr.pointee.sin_addr = self.in_addr
            }
        }
        return addr
    }

}

public extension IPv6Address {

    init?(addrInfo: addrinfo) {
        guard addrInfo.ai_family == AF_INET6 else { return nil }

        let addressData = addrInfo.ai_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { ptr -> Data in
            return Data(bytes: &ptr.pointee.sin6_addr, count: MemoryLayout<in6_addr>.size)
        }

        self.init(addressData)
    }

}
