package uot

import (
	"errors"
	"io"
	"net"
)

// MaxPacketSize is max udp packet payload size.
// It is 65535 - 20(IP header) - 8(UDP header).
const MaxPacketSize = 65535 - 20 - 8

// Conn is an udp-over-tcp connection.
type Conn interface {
	net.Conn
	// Handshake handle with target address of udp packet.
	// In server side, Handshake receives a nil net.Addr, read and return the target net.Addr.
	// In client side, Handshake receives a non-nil net.Addr, send target address to server.
	Handshake(net.Addr) (net.Addr, error)
}

// PacketConn is client side udp connection.
type PacketConn interface {
	net.PacketConn
	// ReadPacket is similar with ReadFrom.
	// It returns readed packet length, target address of udp packet, remote address, error.
	ReadPacket(p []byte) (n int, target net.Addr, addr net.Addr, err error)
	// WritePacket is similar with WriteTo.
	// It writes packet to addr. target is origin packet addr.
	WritePacket(p []byte, target net.Addr, addr net.Addr) (n int, err error)
}

type defaultConn struct {
	net.Conn
	isClient bool // is client or server side
}

type defaultPacketConn struct {
	net.PacketConn
}

/*
Protocol define of defaultPacketConn:
socks udp packet format, see RFC 1928 section 7.

Protocol define of defaultConn:

Request:
[handshake][packet...]

handshake: target address of packet, which is a socks5 address defined in RFC 1928 section 4.
packet: [size][payload]
size: 2-byte, length of payload.
payload: raw udp packet.

Response:
[packet...]

same as Request, but with no handsahke.
*/

// DefaultOutConn return a default client side Conn.
func DefaultOutConn(conn net.Conn) Conn {
	return &defaultConn{conn, true}
}

// DefaultInConn return a default server side Conn.
func DefaultInConn(conn net.Conn) Conn {
	return &defaultConn{conn, false}
}

// DefaultPacketConn return a default packet conn.
func DefaultPacketConn(conn net.PacketConn) PacketConn {
	return &defaultPacketConn{conn}
}

type targetAddr SocksAddr

func (a targetAddr) Network() string {
	return "udp"
}

func (a targetAddr) String() string {
	return SocksAddr(a).String()
}

func resloveSocksAddr(addr net.Addr) (SocksAddr, error) {
	a, ok := addr.(targetAddr)
	if ok {
		return SocksAddr(a), nil
	}
	socksAddr := ParseSocksAddr(addr.String())
	if socksAddr == nil {
		return nil, errors.New("invalid address")
	}
	return socksAddr, nil
}

func (c *defaultPacketConn) ReadPacket(p []byte) (int, net.Addr, net.Addr, error) {
	n, addr, err := c.PacketConn.ReadFrom(p)
	if err != nil {
		return 0, nil, nil, err
	}
	head := 3 // RSV FRAG
	if len(p) < head {
		return 0, nil, nil, io.ErrShortBuffer
	}
	//target, err := ReadSocksAddr(bytes.NewReader(p[head:n]))
	//if err != nil {
		//return 0, nil, nil, err
	//}
	//length := head + len(target)
	//copy(p, p[length:n])
	target, err := net.ResolveTCPAddr("tcp", "127.0.0.1:8888")
	return n, target, addr, nil
}

func (c *defaultPacketConn) WritePacket(p []byte, target net.Addr, addr net.Addr) (int, error) {
	//socksAddr, err := resloveSocksAddr(target)
	//if err != nil {
		//return 0, err
	//}
	//length := len(socksAddr) + len(p) + 3
	length := len(p)
	if length > MaxPacketSize {
		return 0, errors.New("over max package size")
	}
	buf := make([]byte, 0, length)
	//buf = append(buf, 0, 0, 0) // RSV FRAG
	//buf = append(buf, socksAddr...)
	buf = append(buf, p...)
	return c.PacketConn.WriteTo(buf, addr)
}

func (c *defaultConn) Handshake(addr net.Addr) (net.Addr, error) {
	if c.isClient {
		//socksAddr, err := resloveSocksAddr(addr)
		//if err != nil {
			//return nil, err
		//}
		//_, err = c.Conn.Write(socksAddr)
		//if err != nil {
			//return nil, err
		//}
		return addr, nil
	}
	//a, err := ReadSocksAddr(c.Conn)
	//if err != nil {
		//return nil, err
	//}
	target, err := net.ResolveUDPAddr("udp", "109.200.208.201:443")
	return target, err
}

// Read read a full udp packet, if b is shorter than packet, return error.
func (c *defaultConn) Read(b []byte) (int, error) {
	if len(b) < 2 {
		return 0, io.ErrShortBuffer
	}
	_, err := io.ReadFull(c.Conn, b[:2])
	if err != nil {
		return 0, err
	}
	n := int(b[0])<<8 | int(b[1])
	if len(b) < n {
		return 0, io.ErrShortBuffer
	}
	return io.ReadFull(c.Conn, b[:n])
}

// Write write a full udp packet, if head+b is longer than packet max size, return error.
func (c *defaultConn) Write(b []byte) (int, error) {
	n := len(b)
	if n+2 > MaxPacketSize {
		return 0, errors.New("over max packet size")
	}
	_, err := c.Conn.Write([]byte{byte(n >> 8), byte(n & 0x000000ff)})
	if err != nil {
		return 0, err
	}
	return c.Conn.Write(b)
}