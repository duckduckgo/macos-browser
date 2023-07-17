package main

import (
	"flag"
	"log"
	"net"

	uot "github.com/justlovediaodiao/udp-over-tcp"
)

type config struct {
	listen  string
	server  string
	verbose bool
}

func main() {
	var conf config
	flag.StringVar(&conf.listen, "l", "", "listen address")
	flag.StringVar(&conf.server, "s", "", "(client-only) server listen address")
	flag.BoolVar(&conf.verbose, "v", false, "log verbose info")
	flag.Parse()

	if conf.listen == "" {
		flag.Usage()
		return
	}
	if conf.server != "" {
		startClient(&conf)
	} else {
		startServer(&conf)
	}
}

func startServer(conf *config) error {
	l, err := net.Listen("tcp", conf.listen)
	if err != nil {
		log.Printf("listen error: %s", err)
		return err
	}
	var server uot.Server
	if conf.verbose {
		server.Logf = log.Printf
	}
	for {
		conn, err := l.Accept()
		if err != nil {
			log.Printf("accept error: %s", err)
			continue
		}
		go server.Serve(uot.DefaultInConn(conn))
	}
}

func startClient(conf *config) error {
	conn, err := net.ListenPacket("udp", conf.listen)
	if err != nil {
		log.Printf("listen packet error: %s", err)
		return err
	}
	client := uot.Client{
		Dialer: func(addr string) (uot.Conn, error) {
			conn, err := net.Dial("tcp", addr)
			if err != nil {
				return nil, err
			}
			return uot.DefaultOutConn(conn), nil
		},
	}
	if conf.verbose {
		client.Logf = log.Printf
	}
	client.Serve(uot.DefaultPacketConn(conn), conf.server)
	return nil
}
