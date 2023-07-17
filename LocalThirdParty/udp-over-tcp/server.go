package uot

import (
	"errors"
	"net"
	"os"
	"time"
)

// Server server.
type Server struct {
	// Logf is log func, default nil, no log output.
	Logf func(string, ...interface{})
}

func (s *Server) logf(format string, v ...interface{}) {
	if s.Logf != nil {
		s.Logf(format, v...)
	}
}

// Serve read packet over tcp connection and send to target address in udp.
// read response from target address and send to address on the connection.
func (s *Server) Serve(conn Conn) error {
	// handshake, read target addr.
	addr, err := conn.Handshake(nil)
	if err != nil {
		s.logf("handshake error: %s", err)
		return err
	}
	rc, err := net.ListenPacket("udp", "")
	if err != nil {
		s.logf("listen error: %s", err)
		return err
	}
	s.logf("%s <---> %s", conn.RemoteAddr().String(), addr.String())
	err = s.relay(conn, rc, addr)
	if err != nil {
		s.logf("relay error: %s", err)
	}
	return err
}

// relay copy between tcp and udp conn until timeout.
func (s *Server) relay(conn Conn, rc net.PacketConn, addr net.Addr) error {
	udpAddr, ok := addr.(*net.UDPAddr)
	if !ok {
		var err error
		udpAddr, err = net.ResolveUDPAddr(addr.Network(), addr.String())
		if err != nil {
			return err
		}
	}

	done := make(chan error, 1)
	// relay from tcp to udp
	go func() {
		defer rc.SetReadDeadline(time.Now()) // wake up anthoer goroutine
		buf := make([]byte, MaxPacketSize)
		for {
			n, err := conn.Read(buf)
			if err != nil {
				done <- err
				return
			}
			_, err = rc.WriteTo(buf[:n], udpAddr)
			if err != nil {
				done <- err
				return
			}
		}
	}()

	// relay from udp to tcp
	var err error
	var n int
	buf := make([]byte, MaxPacketSize)
	for {
		n, _, err = rc.ReadFrom(buf)
		if err != nil {
			break
		}
		_, err = conn.Write(buf[:n])
		if err != nil {
			break
		}
	}
	conn.SetReadDeadline(time.Now()) // wake up anthoer goroutine

	// ignore timeout error.
	err1 := <-done
	if !errors.Is(err, os.ErrDeadlineExceeded) {
		return err
	}
	if !errors.Is(err1, os.ErrDeadlineExceeded) {
		return err1
	}
	return nil
}
