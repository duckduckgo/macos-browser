//
//  Pinger.swift
//  DuckDuckGo
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

// swiftlint:disable identifier_name

import Darwin
import Foundation
import Common
import Network
import QuartzCore

/// Latency measurement class (Pinger)
/// For reference see:
///  http://www.ping127001.com/pingpage/ping.text
///  https://github.com/samiyr/SwiftyPing
///  https://github.com/naptics/PlainPing
///  https://github.com/openbsd/src/blob/master/sbin/ping/ping.c
///
/// Usage:
///
///     Task {
///         let pinger = try! Pinger(ip: IPv4Address("8.8.8.8")!, timeout: 10, log: .default)
///         while true {
///             do {
///                 _=try await pinger.ping().get()
///             } catch {
///                 print("error:", error)
///             }
///             try! await Task.sleep(for: .seconds(1))
///         }
///     }
///     // prevent console tool from exiting
///     RunLoop.main.run()
///
public final class Pinger: @unchecked Sendable {

    /// host to ping
    private let ip: IPv4Address

    /// Pinger identifier
    private let id: UUID
    /// ping request sequence number
    private var seq: UInt32 = 0
    private func nextSeq() -> UInt32 {
        dispatchPrecondition(condition: .onQueue(queue))
        defer {
            if seq < UInt32.max {
                seq += 1
            } else {
                seq = 0
            }
        }
        return seq
    }
    /// ping request timeout
    let timeout: TimeInterval
    /// socket TTL
    let ttl: Int?

    private let getLogger: (() -> OSLog)
    private var log: OSLog {
        getLogger()
    }

    private let queue: DispatchQueue
    /// sent request ids
    private var sentIndices = IndexSet()

    public enum Constants {
        public static let defaultTimeout: TimeInterval = 10
    }

    public init(ip: IPv4Address,
                id: UUID = UUID(),
                ttl: Int? = nil,
                timeout: TimeInterval = Constants.defaultTimeout,
                queue: DispatchQueue = DispatchQueue(label: "Pinger"),
                log: @autoclosure @escaping (() -> OSLog) = .disabled) {

        self.ip = ip
        self.id = id
        self.ttl = ttl
        self.timeout = timeout
        self.queue = queue
        self.getLogger = log
    }

    public func ping(completion: @escaping (Result<PingResult, PingError>) -> Void) {
        func mainQueueCompletion(_ r: Result<PingResult, PingError>) {
            DispatchQueue.main.async {
                completion(r)
            }
        }
        queue.async { [weak self] in
            guard let self else { return mainQueueCompletion(.failure(.cancelled)) }

            let r = self.ping_unsafe()
            mainQueueCompletion(r)
        }
    }

    public func ping() async -> Result<PingResult, PingError> {
        await withUnsafeContinuation { continuation in
            queue.async { [self /* held by async call */] in
                let r = self.ping_unsafe()
                continuation.resume(with: .success(r))
            }
        }
    }

}

public extension Pinger {

    struct PingResult {
        /// server IP (use .description for String value)
        public let ip: IPv4Address
        /// response size
        public let bytesCount: Int
        /// ping request sequence number
        public let seq: Int
        ///
        public let ttl: Int
        /// latency
        public let time: TimeInterval
    }

    enum PingError: Error {
        case socket
        case send(SendError)
        case response(ResponseError)
        case timeout(TimeoutKind)
        case cancelled

        public enum SendError {
            case tooShort(Int)
            case errno(errno_t)
        }
        public enum ResponseError {
            case tooShort(Int)
            case validation(ICMPValidationError)
            case errno(errno_t)
            case connectionClosed
        }
        public enum TimeoutKind {
            case send    // timeouted on socket.send
            case select  // timeouted on socket.select
            case intrans // timexceed on socket.recv: ttl==0 in transit
            case reass   // timexceed on socket.recv: ttl==0 in reass
            case gaveup  // gave up trying to receive
        }
    }

    enum ICMPValidationError {
        case invalidChecksum(received: UInt16, calculated: UInt16)

        case wrongId(UUID)
        case wrongIndex(UInt32)
        case wrongTimestamp(received: CFTimeInterval, expected: CFTimeInterval)

        case failure(ICMPTypeCode)
        case unknown(type: u_char, code: u_char)
    }

    enum ICMPTypeCode {
        case echoreply                  // 0  echo reply
        case unreach(Unreach)           // 3  dest unreachable, codes:
        public enum Unreach: u_char {
            case net               = 0  // bad net
            case host              = 1  // bad host
            case `protocol`        = 2  // bad protocol
            case port              = 3  // bad port
            case needfrag          = 4  // IP_DF caused drop
            case srcfail           = 5  // src route failed
            case net_unknown       = 6  // unknown net
            case host_unknown      = 7  // unknown host
            case isolated          = 8  // src host isolated
            case net_prohib        = 9  // prohibited access
            case host_prohib       = 10 // ditto
            case tosnet            = 11 // bad tos for net
            case toshost           = 12 // bad tos for host
            case filter_prohib     = 13 // admin prohib
            case host_precedence   = 14 // host prec vio.
            case precedence_cutoff = 15 // prec cutoff
        }

        case sourcequench               // 4  packet lost, slow down
        case redirect(Redirect)         // 5  shorter route, codes:
        public enum Redirect: u_char {
            case net               = 0  // for network
            case host              = 1  // for host
            case tosnet            = 2  // for tos and net
            case toshost           = 3  // for tos and host
        }

        case althostaddr                // 6  alternate host address

        case routersolicit              // 10 router solicitation
        case timxceed(Timexceed)        // 11 time exceeded, code:
        public enum Timexceed: u_char {
            case intrans           = 0  // ttl==0 in transit
            case reass             = 1  // ttl==0 in reass
        }

        case paramprob(Paramprob)       // 12 ip header bad
        public enum Paramprob: u_char {
            case erratptr          = 0  // error at param ptr
            case optabsent         = 1  // req. opt. absent
            case length            = 2  // bad length
        }

        case tstamp                     // 13 timestamp request
        case tstampreply                // 14 timestamp reply
        case ireq                       // 15 information request
        case ireqreply                  // 16 information reply
        case maskreq                    // 17 address mask request
        case maskreply                  // 18 address mask reply
        case traceroute                 // 30 traceroute
        case dataconverr                // 31 data conversion error
        case mobile_redirect            // 32 mobile host redirect
        case ipv6_whereareyou           // 33 IPv6 where-are-you
        case ipv6_iamhere               // 34 IPv6 i-am-here
        case mobile_regrequest          // 35 mobile registration req
        case mobile_regreply            // 36 mobile registration reply
        case skip                       // 39 SKIP
        case photuris(Photuris)         // 40 Photuris
        public enum Photuris: u_char {
            case unknown_index     = 1  // unknown sec index
            case auth_failed       = 2  // auth failed
            case decrypt_failed    = 3  // decrypt failed
        }

        // swiftlint:disable:next cyclomatic_complexity
        public init?(type: u_char, code: u_char) {
            switch type {
            case  0:
                guard code == 0 else { return nil }
                self = .echoreply
            case  3:
                guard let code = Unreach(rawValue: code) else { return nil }
                self = .unreach(code)
            case  4: self = .sourcequench
            case  5:
                guard let code = Redirect(rawValue: code) else { return nil }
                self = .redirect(code)
            case  6: self = .althostaddr
            case 10: self = .routersolicit
            case 11:
                guard let code = Timexceed(rawValue: code) else { return nil }
                self = .timxceed(code)
            case 12:
                guard let code = Paramprob(rawValue: code) else { return nil }
                self = .paramprob(code)
            case 13: self = .tstamp
            case 14: self = .tstampreply
            case 15: self = .ireq
            case 16: self = .ireqreply
            case 17: self = .maskreq
            case 18: self = .maskreply
            case 30: self = .traceroute
            case 31: self = .dataconverr
            case 32: self = .mobile_redirect
            case 33: self = .ipv6_whereareyou
            case 34: self = .ipv6_iamhere
            case 35: self = .mobile_regrequest
            case 36: self = .mobile_regreply
            case 39: self = .skip
            case 40:
                guard let code = Photuris(rawValue: code) else { return nil }
                self = .photuris(code)
            default: return nil
            }
        }
    }

}

// MARK: - Private

extension Pinger {

    func ping_unsafe() -> Result<PingResult, PingError> {
        dispatchPrecondition(condition: .onQueue(queue))

        // open socket
        guard var socket = Socket(internetwork: AF_INET, socketType: SOCK_DGRAM, protocol: IPPROTO_ICMP) else { return .failure(.socket) }
        socket.noSigPipe = true
        socket.timeout = timeout
        if let ttl {
            socket.ttl = ttl
        }
        defer { socket.close() }

        // increment seq index
        let seq = self.nextSeq()
        sentIndices.insert(Int(seq))

        os_log("PING %s: %d data bytes", log: log, ip.debugDescription, MemoryLayout<ICMP>.size)
        // form ICMP packet with id, icmp_seq, timestamp and checksum
        let icmp = ICMP(id: id, index: seq)

        // send ping
        let sendResult = send(icmp, using: socket)
        guard case .success = sendResult else { return sendResult.map { fatalError("unreachable") } }

        // receive pong
        let receiveResult = receive(sent: icmp, using: socket)
        return receiveResult
    }

    func send(_ icmp: ICMP, using socket: Socket) -> Result<Void, PingError> {
        do {
            try socket.send(icmp, to: ip)
        } catch let error as Socket.Error {
            switch error {
            case Socket.Error.errno(EAGAIN),
                Socket.Error.errno(EWOULDBLOCK),
                    .timeout,
                    .connectionClosed:
                return .failure(.timeout(.send))
            case .errno(let errno):
                return .failure(.send(.errno(errno)))
            case .tooShort(let bytesCount):
                return .failure(.send(.tooShort(bytesCount)))
            }
        } catch {
            assertionFailure("unexpected \(error)")
            return .failure(.cancelled)
        }

        return .success( () )
    }

    func receive(sent icmp: ICMP, using socket: Socket) -> Result<PingResult, PingError> {
        var bytesCount = 0
        while icmp.timestamp + timeout > CACurrentMediaTime() {
            do {
                // receive
                var ip = Darwin.ip()
                let timeout = icmp.timestamp + timeout - CACurrentMediaTime()
                let response = try socket.receive(ICMP.self, sender: &ip, count: &bytesCount, timeout: timeout)
                let end = CACurrentMediaTime()

                // validate
                if let validationError = response.validate(withId: id, sentSequenceIndices: sentIndices) {
                    return .failure(validationError)
                }
                guard response.index == icmp.index else {
                    // the response is for failed or timeouted request, ignore it
                    continue
                }
                guard response.timestamp == icmp.timestamp else {
                    // timestamp for same seq index should match
                    return .failure(.response(.validation(.wrongTimestamp(received: response.timestamp, expected: icmp.timestamp))))
                }
                let srcIp = IPv4Address(in_addr: ip.ip_src) ?? {
                    assertionFailure("could not get src ip address")
                    return self.ip
                }()
                let r = PingResult(ip: srcIp, bytesCount: bytesCount, seq: Int(response.index), ttl: Int(ip.ip_ttl), time: end - icmp.timestamp)
                os_log("%d bytes from %s: icmp_seq=%d ttl=%d time=%.3f ms", log: log, r.bytesCount, r.ip.debugDescription, r.seq, r.ttl, r.time * 1000)

                return .success(r)

            } catch let error as Socket.Error {
                switch error {
                case .tooShort(let bytesCount):
                    return .failure(.response(.tooShort(bytesCount)))
                case .errno(let errno):
                    return .failure(.response(.errno(errno)))
                case .timeout:
                    return .failure(.timeout(.select))
                case .connectionClosed:
                    return .failure(.response(.connectionClosed))
                }
            } catch {
                assertionFailure("unexpected \(error)")
                return .failure(.cancelled)
            }
        }

        return .failure(.timeout(.gaveup))
    }

}

struct ICMP {

    /// icmp.icmp_type
    var type: u_char
    /// icmp.icmp_code
    var code: u_char
    /// icmp.icmp_cksum
    var checksum: UInt16 = 0
    /// joined icp.icmp_hun.ih_idseq.icd_id: UInt16 and icp.icmp_hun.ih_idseq.icd_seq: UInt16
    var index: UInt32
    /// timestamp
    var timestamp: CFTimeInterval
    /// payload
    var uuid: UUID

    init(id: UUID, index: UInt32) {
        self.type = u_char(ICMP_ECHO)
        self.code = 0
        self.index = index
        self.timestamp = CACurrentMediaTime()
        self.uuid = id

        self.checksum = self.calculateChecksum()
    }

    func calculateChecksum() -> UInt16 {
        return withUnsafePointer(to: self) {
            var w = $0.withMemoryRebound(to: u_short.self, capacity: MemoryLayout<Self>.size / MemoryLayout<u_short>.size) { $0 }
            var sum: UInt64 = 0

            /**
             *  Our algorithm is simple, using a 32 bit accumulator (sum),
             *  we add sequential 16 bit words to it, and at the end, fold
             *  back all the carry bits from the top 16 bits into the lower
             *  16 bits.
             */
            for _ in 0..<(MemoryLayout<Self>.size / MemoryLayout<u_short>.size) {
                sum += UInt64(w.pointee)
                w = w.advanced(by: 1)
            }

            // add back carry outs from top 16 bits to low 16 bits
            while sum >> 16 != 0 {
                sum = (sum >> 16) + (sum & 0xffff) // add hi 16 to low 16
                sum += (sum >> 16) // add carry
            }

            return ~UInt16(sum) // truncate to 16 bits
        }
    }

    func validate(withId id: UUID, sentSequenceIndices: IndexSet) -> Pinger.PingError? {
        guard let typeCode = Pinger.ICMPTypeCode(type: type, code: code) else {
            return .response(.validation(.unknown(type: type, code: code)))
        }
        switch typeCode {
        case .echoreply:
            break // ok
        case .timxceed(.intrans):
            return .timeout(.intrans)
        case .timxceed(.reass):
            return .timeout(.reass)
        default:
            return .response(.validation(.failure(typeCode)))
        }
        // checksum should result to 0 when self.checksum != 0
        guard self.calculateChecksum() == 0 else {
            var zeroedChecksum = self
            zeroedChecksum.checksum = 0
            return .response(.validation(.invalidChecksum(received: self.checksum, calculated: zeroedChecksum.calculateChecksum())))
        }
        guard self.uuid == id else {
            return .response(.validation(.wrongId(self.uuid)))
        }
        // request with the index should‘ve been sent before
        guard sentSequenceIndices.contains(Int(index)) else {
            return .response(.validation(.wrongIndex(index)))
        }

        return nil
    }

}

struct Socket {

    let socket: Int32

    init?(internetwork: Int32, socketType: Int32, protocol proto: Int32) {
        self.socket = Darwin.socket(internetwork, socketType, proto)
        if socket < 0 {
            return nil
        }
    }

    func getopt<T>(_ level: Int32, _ opt: Int32) -> T {
        return withUnsafeTemporaryAllocation(of: socklen_t.self, capacity: 1) { socklen in
            withUnsafeTemporaryAllocation(of: T.self, capacity: 1) { value in
                _=getsockopt(socket, SOL_SOCKET, opt, value.baseAddress, socklen.baseAddress)
                return value.baseAddress!.pointee
            }
        }
    }

    func setopt<T>(_ level: Int32, _ opt: Int32, value: T) {
        var value = value
        let result = setsockopt(socket, level, opt, &value, socklen_t(MemoryLayout<T>.size))
        assert(result == 0)
    }

    var noSigPipe: Bool {
        get {
            getopt(SOL_SOCKET, SO_NOSIGPIPE) != 0
        }
        set {
            setopt(SOL_SOCKET, SO_NOSIGPIPE, value: newValue ? 1 : 0)
        }
    }

    var timeout: TimeInterval {
        get {
            let timeval = getopt(SOL_SOCKET, SO_SNDTIMEO) as timeval
            return Double(timeval.tv_sec) + Double(timeval.tv_usec) / 1_000_000
        }
        set {
            let timeval = timeval(tv_sec: Int(newValue), tv_usec: Int32((newValue - Double(Int(newValue))) * 1_000_000))
            setopt(SOL_SOCKET, SO_SNDTIMEO, value: timeval)
        }
    }

    var ttl: Int {
        get {
            getopt(IPPROTO_IP, IP_TTL)
        }
        set {
            setopt(IPPROTO_IP, IP_TTL, value: newValue)
        }
    }

    func send(_ buffer: UnsafeRawBufferPointer, to ip: IPv4Address) throws {
        try withUnsafePointer(to: ip.sockaddr) { whereto in
            let bytesSent = sendto(socket, buffer.baseAddress, buffer.count, 0, whereto, socklen_t(MemoryLayout<sockaddr>.size))
            switch bytesSent {
            case buffer.count:
                break
            case 0:
                throw Error.connectionClosed
            case ..<0:
                throw Error.errno(errno)
            default:
                throw Error.tooShort(bytesSent)
            }
        }
    }

    func send<T>(_ value: T, to ip: IPv4Address) throws {
        try withUnsafePointer(to: value) {
            let buffer = UnsafeRawBufferPointer(start: $0, count: MemoryLayout<T>.size)
            try send(buffer, to: ip)
        }
    }

    private enum Constants {
        // keep max packet size below 1024 to use Temporary Allocation on the Stack
        static let maxPacket = 1024
    }

    enum Error: Swift.Error {
        case errno(errno_t)
        case tooShort(Int)
        case timeout
        case connectionClosed
    }

    func receive<R>(timeout: TimeInterval, _ consume: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R {
        // set up the select function
        var readFDSet = fd_set()
        bzero(&readFDSet, MemoryLayout.size(ofValue: readFDSet))
        __darwin_fd_set(socket, &readFDSet)
        // `select` timeout
        var timeval = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout - Double(Int(timeout))) * 1_000_000))
        let maxFD = socket + 1

        // wait for data to become available for reading
        let selectResult = select(maxFD, &readFDSet, nil, nil, &timeval)
        switch selectResult {
        case 0:
            throw Error.timeout
        case ..<0:
            throw Error.errno(errno)
        default: break
        }

        guard __darwin_fd_isset(socket, &readFDSet) != 0 else {
            throw Error.errno(errno)
        }

        // socket is ready for reading
        return try withUnsafeTemporaryAllocation(byteCount: Constants.maxPacket, alignment: MemoryLayout<UInt8>.alignment) { buffer in
            let bytesRead = recv(socket, buffer.baseAddress, buffer.count, 0)

            switch bytesRead {
            case 0:
                throw Error.connectionClosed
            case ..<0:
                throw Error.errno(errno)
            default: break
            }

            return try consume(UnsafeMutableRawBufferPointer(start: buffer.baseAddress, count: bytesRead))
        }
    }

    func receive<R>(_ type: R.Type, sender ip: inout Darwin.ip, count: inout Int, timeout: TimeInterval) throws -> R {
        assert(MemoryLayout<Darwin.ip>.size + MemoryLayout<R>.size < Constants.maxPacket)

        // receive data into temporary buffer
        return try receive(timeout: timeout) { buffer in
            count = buffer.count
            guard let ptr = buffer.baseAddress else { throw Error.tooShort(-1) }
            guard count >= MemoryLayout<Darwin.ip>.size + MemoryLayout<R>.size else { throw Error.tooShort(count) }

            // read header
            ip = ptr.bindMemory(to: Darwin.ip.self, capacity: 1).pointee
            let hlen = Int(ip.ip_hl << 2)

            guard count >= hlen + MemoryLayout<R>.size else { throw Error.tooShort(count) }

            // read payload
            return ptr.advanced(by: hlen).bindMemory(to: type, capacity: 1).pointee
        }
    }

    func close() {
        Darwin.close(socket)
    }

}

// swiftlint:enable identifier_name
