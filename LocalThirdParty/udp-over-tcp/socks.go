package uot

import (
	"errors"
	"io"
	"net"
	"strconv"
)

// maxAddrLen is the max size of socks address host in bytes.
const maxAddrLen = 1 + 1 + 255

// socks address type. see RFC 1928.
const (
	atypIPv4       = 1
	atypDomainName = 3
	atypIPv6       = 4
)

// SocksAddr is socks addr defined in RFC 1928.
type SocksAddr []byte

// String return address string.
func (addr SocksAddr) String() string {
	var host string
	switch addr[0] {
	case atypDomainName:
		host = string(addr[2 : 2+int(addr[1])])
	case atypIPv4:
		host = net.IP(addr[1 : 1+4]).String()
	case atypIPv6:
		host = net.IP(addr[1 : 1+16]).String()
	default:
		panic("error socks address")
	}
	buf := addr[len(addr)-2:]
	port := strconv.Itoa((int(buf[0]) << 8) | int(buf[1]))
	return net.JoinHostPort(host, port)
}

// ReadSocksAddr read socks addr.
func ReadSocksAddr(r io.Reader) (SocksAddr, error) {
	buf := make([]byte, maxAddrLen)
	var n int
	nn, err := io.ReadFull(r, buf[:1]) // read 1st byte for address type
	if err != nil {
		return nil, err
	}
	n += nn
	switch buf[0] {
	case atypDomainName:
		nn, err = io.ReadFull(r, buf[1:2]) // read 2nd byte for domain length
		if err != nil {
			return nil, err
		}
		n += nn
		nn, err = io.ReadFull(r, buf[2:2+int(buf[1])])
	case atypIPv4:
		nn, err = io.ReadFull(r, buf[1:1+4])
	case atypIPv6:
		nn, err = io.ReadFull(r, buf[1:1+16])
	default:
		err = errors.New("error socks address")
	}
	if err != nil {
		return nil, err
	}
	n += nn
	// read 2-byte port
	nn, err = io.ReadFull(r, buf[n:n+2])
	n += nn
	return buf[:n], nil
}

// ParseSocksAddr parses the address in string s. Returns nil if failed.
func ParseSocksAddr(s string) SocksAddr {
	var addr SocksAddr
	host, port, err := net.SplitHostPort(s)
	if err != nil {
		return nil
	}
	if ip := net.ParseIP(host); ip != nil {
		if ip4 := ip.To4(); ip4 != nil {
			addr = make([]byte, 1+net.IPv4len+2)
			addr[0] = atypIPv4
			copy(addr[1:], ip4)
		} else {
			addr = make([]byte, 1+net.IPv6len+2)
			addr[0] = atypIPv6
			copy(addr[1:], ip)
		}
	} else {
		if len(host) > 255 {
			return nil
		}
		addr = make([]byte, 1+1+len(host)+2)
		addr[0] = atypDomainName
		addr[1] = byte(len(host))
		copy(addr[2:], host)
	}

	portnum, err := strconv.ParseUint(port, 10, 16)
	if err != nil {
		return nil
	}

	addr[len(addr)-2], addr[len(addr)-1] = byte(portnum>>8), byte(portnum)

	return addr
}
