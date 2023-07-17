package uot

import (
	"errors"
	"net"
	"os"
	"time"
)

const (
	relayTimeout  = time.Minute * 5
	packetBufSize = 2048
)

// Client is client.
type Client struct {
	// Dialer dial tcp to server and return a Conn.
	Dialer func(string) (Conn, error)
	// Timeout is used to close an inactive connection, default 5min.
	// Since udp is not connection based, we donot know when a udp connection closed.
	Timeout time.Duration
	// BufSize is max buffered udp packet count, default 8.
	// Since there's no Congestion-Control in udp,
	// if a large number of UDP packets arrived, there's no time to send it to remote over tcp.
	// if buffer is full, new udp packet will be dropped.
	BufSize int
	// Logf is log func, default nil, no log output.
	Logf func(string, ...interface{})
}

func (c *Client) logf(format string, v ...interface{}) {
	if c.Logf != nil {
		c.Logf(format, v...)
	}
}

func (c *Client) timeout() time.Duration {
	if c.Timeout > 0 {
		return c.Timeout
	}
	return relayTimeout
}

func (c *Client) bufSize() int {
	if c.BufSize > 0 {
		return c.BufSize
	}
	return packetBufSize
}

// Serve read udp packet and send to server over tcp.
// read response from server and send to address on the packet.
func (c *Client) Serve(conn PacketConn, server string) {
	buf := make([]byte, MaxPacketSize)
	nat := nat{
		m: make(map[string]chan []byte),
	}
	for {
		n, target, addr, err := conn.ReadPacket(buf)
		if err != nil {
			if errors.Is(err, net.ErrClosed) {
				c.logf("udp listenner closed, exit")
				return
			} else {
				c.logf("read packet error: %s", err)
			}
			continue
		}
		key := addr.String()
		pbuf := nat.Get(key)
		if pbuf == nil {
			pbuf = make(chan []byte, c.bufSize())
			nat.Set(key, pbuf)
			go func() {
				rc, err := c.Dialer(server)
				if err != nil {
					c.logf("dial to %s error: %s", server, err)
					return
				}
				defer rc.Close()
				c.logf("%s <---> %s <---> %s", key, server, target.String())
				// handshake, send target addr to remote.
				_, err = rc.Handshake(target)
				if err != nil {
					c.logf("handshake error: %s", err)
					return
				}
				err = c.relay(conn, rc, target, addr, pbuf)
				if err != nil {
					c.logf("relay error: %s", err)
				}
				nat.Del(key)
			}()
		}
		b := make([]byte, n)
		copy(b, buf)
		select {
		case pbuf <- b:
		default:
			c.logf("drop packet from %s", key)
		}
	}
}

// relay copy between udp and tcp conn until timeout.
func (c *Client) relay(conn PacketConn, rc Conn, target net.Addr, addr net.Addr, pbuf chan []byte) error {
	done := make(chan error, 1)
	// relay from udp to tcp
	go func() {
		defer rc.SetReadDeadline(time.Now()) // wake up anthoer goroutine
		for {
			t := time.NewTimer(c.timeout())
			select {
			case buf := <-pbuf:
				if buf == nil {
					done <- nil
					return
				}
				_, err := rc.Write(buf)
				if err != nil {
					done <- err
					return
				}
			case <-t.C:
				done <- nil
				return
			}
			t.Stop()
		}
	}()

	// relay from tcp to udp
	var err error
	var n int
	buf := make([]byte, MaxPacketSize)
	for {
		n, err = rc.Read(buf)
		if err != nil {
			break
		}
		_, err = conn.WritePacket(buf[:n], target, addr)
		if err != nil {
			break
		}
	}
	pbuf <- nil // wake up anthoer goroutine

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
